/*
MAA2+ v0.42
=========

Updated version of the MAA antialising script from AnimeIVTC.
MAA2 uses tp7's SangNom2, which provide a nice speedup for SangNom-based antialiasing,
especially when only processing the luma plane.
The defaults of MAA2 match up with MAA, so you'll get identical output (save for the more accurate border region processing of SangNom2)
when using this script as a drop-in replacement.

MAA2 supports Y8, YV12, YV16 and YV24 input.

Requirements:

   * AviSynth+
   * SangNom2 0.3+
   * Masktools 2.0b1

Parameters:

   + [int] mask (1)
       *   0: Disable masking
       *   1: Enable masking
       *  -i: Enable masking with custom treshold (sensible values are between 0 and 30)
   + [bool] chroma (false)
       *   false: Don't process chroma channels (copy UV from the source clip if present)
       *   true: Process chroma channels
   + [float] ss (2.0)
       *   Supersampling factor (sensible values are between 2.0 and 4.0 for HD content)
   + [int] aa (48)
       *   Sangnom2 luma antialiasing strength
   + [int] aac (aa-8)
       *   Sangnom2 chroma antialiasing strength
   + [int] threads (4)
       *   Number of threads used by every Sangnom2 instance
   + [int] show (0)
       *   0: Don't overlay mask
       *   1: Overlay mask only
       *   2: Overlay mask and run antialiasing on the luma plane

*/

function maa2(clip c, int "mask", bool "chroma", float "ss", int "aa", int "aac", int "threads", int "show")
{
    chroma = Default(chroma, false)
    mask   = Default(mask, 1)
    mtresh = (mask < 0) ? -mask : 7
    show   = Default(show, 0)
    uv     = (chroma) ? 3 : 1

    Assert(c.IsY8 || c.IsYV12 || c.IsYV24 || c.IsYV16, "MAA2: Input must be Y8, YV12, YV16 or YV24")
    Assert(0 <= show <= 2, "MAA2: Parameter 'show' must be between 0 and 2")

    # create mask
    if (mask != 0) {
        m = c.mt_edge("sobel", mtresh, mtresh, mtresh-6, mtresh-6, u=uv, v=uv).mt_inflate(u=uv, v=uv)
    }

    # run sangnom2-based aa
    if (!chroma || show > 0) {
        c_aa = c.ConvertToY8().Sangnom2AA(ss, aa, threads=threads)
    }
    else if (c.IsYV16) {
        c_aa_u = c.UtoY8().Sangnom2AA(ss, aac, threads=threads)
        c_aa_v = c.VtoY8().Sangnom2AA(ss, aac, threads=threads)
        c_aa = YToUV(c_aa_u, c_aa_v, c.ConvertToY8().Sangnom2AA(ss, aa, threads=threads))
    }
    else { c_aa = c.Sangnom2AA(ss, aa, aac, threads) }

    # prepare chroma planes for mask overlay
    if (show == 1) {
        c_aa = (c.IsY8) ? c.ConvertToYV12().mt_lut(y=2, u=0, v=0)
                      \ : c.mt_lut("x 2 /", y=2, u=3, v=3)
    }
    else if (show == 2) {
        c_aa = (c.IsY8) ? c_aa.ConvertToYV12().mt_lut(y=2, u=0, v=0)
                      \ : YtoUV(c.UtoY8(), c.VtoY8(), c_aa).mt_lut("x 2 /", y=2, u=3, v=3)
    }

    # merge aa'ed lines into source
    if (mask == 0) {
        return mt_logic(c_aa, "and", y=4, u=2, v=2)
    }
    else if (show > 0) {
        if (c.IsYV16) {
            m_uv = BilinearResize(m, m.width/2, m.height)
            return mt_merge(c, c_aa, YtoUV(m_uv, m_uv, m), u=3, v=3)
        }
        else {
            return (c.IsYV24) ? mt_merge(c, c_aa, m.YtoUV(m,m), u=3, v=3)
                            \ : mt_merge(c.ConvertToYV12(), c_aa, m, u=3, v=3, luma=true)
        }
    }
    else {
        return (chroma) ? mt_merge(c, c_aa, m, u=3, v=3)
                      \ : mt_merge(c, c_aa, m, u=2, v=2)
    }
}

function Sangnom2AA(clip c, float "ss", int "aa", int "aac", int "threads")
{
    threads = Default(threads, 4)
    aa = Default(aa, 48)
    aac = Default(aac, aa-8)
    aac = (aac < 0) ? 0 : aac
    ss = Default(ss, 2.0)
    ss_w = int(round(c.width*ss/4.0)*4)
    ss_h = int(round(c.height*ss/4.0)*4)

    Assert(ss > 0, "MAA2: Supersampling factor must be > 0")

    return c.Spline36Resize(ss_w, ss_h).TurnLeft() \
            .SangNom2(threads=threads, aa=aa, aac=aac).TurnRight().SangNom2(threads=threads, aa=aa, aac=aac).Spline36Resize(c.width, c.height)
}