/*
haa v0.1
====================

Antialiasing script that works both in 16-bit and 8-bit.
Focus is on quality rather than speed, defaults to eedi3 based aa for now.

** WIP - everything subject to change without notice **
still missing: 
   * true 8-bit path for speed (tbd in eedi3_resize16)
   * sharpeners (LSFmod, awarpsharp2?)
   * some mask presets
   * pre-aa downscaling
   * aarepair?
   * visualization of chroma masking

Requirements:
   * AviSynth+ 
   * Dither v1.24.0
   * eedi3 v0.9.2 (Firesledge mod)
   * eedi3_resize16 v0.1
   * nnedi3 v0.9.4
   * nnedi3_resize16 v3.0
   * Contra-Sharpen mod v3.4
   * SmoothAdjust v2.90
   * Masktools v2.0a48tp7fix5
   * LUtils v0.1
   * Resize 8 v1.1
   * RgTools v0.91
   * tmaskcleaner v0.9
   * Sangnom2 v0.35

Input Formats: 
    * Y8/YV12/YV16/YV24 (8-bit or 16-bit stacked)
    * RGB24/RGB32
    * RGB48Y/RGB48YV12
    
    
Parameters:

   + [string] aa (eedi3)
       *   Antiaaliasing method. Currently supported: eedi3, eedi3+sangnom2, sangnom2 
   + [string] ss (Spline36)
       *   Supersampling method. Currently supported: all the AVS+/Dither resizing kernels, nnedi3 (tbd)
   + [float] ssf (1.0 for eedi3/eedi3+sangnom2; 2.0 for sangnom2)
       *   Supersampling factor. Increase this to combat artifacts or excessive blurring.
   + [bool] lsb_in (false), lsb_out (lsb_in)
       *   Tells the script whether the input clips are 16-bit stacked or 8 bit
   + [bool] lsb
       *   Enables/Disables 16-bit processing. Enabled by default if either lsb_in or lsb_out is true. 
       *   Also enabled for RGB processing or when using supersampling kernels only available in Dither.
   + [int] y (3), u (2), v (u)
       *   Processing options for y/u/v planes:
           *  -x..0 : All the pixels of the plane will be set to -x (disables processing)
           *      1 : Disables processing of the plane (plane will contain garbage)
           *      2 : Copies plane from the input clip (disables processing) 
           *      3 : Plane will antialiased and masked
           *      4 : Plane will be antialiased and output as is (ignoring the mask)
   + [string] fmt_in (autodetect) / fmt_out (fmt_in)
       *   Allows you to specify the input and output colorspaces
       *   Specifying fmt_in is required for rgb48y and rgb48yv12
   + [int] dither (6)
       *   Dither mode for conversion from 16-bit to 8-bit (refer to dither docs for more information)
   + [float] ee_fac (2.0)
       *   Scaling factor for eedi3 interpolation.
       *   Using anything other than multiples of two will incur an additional performance hit
   + [various] ee_alpha, ee_beta, ee_gamma, ee_nrad, ee_mdis, ee_hp
       *   Eedi3 parameters (refer to eedi3 docs for more information)
   + [float] sharp (0)
       *   Contra sharpening to be applied to the antialiased clip. Common values are around 100
       *   This parameter is subject to change as other sharpening methods are being added
       *   Sharpening is applied on the supersampled clip after antialiasing.
   + [string] kernel_d (Spline36)
       *   Kernel to use for downscaling back to the source resolution
   + [bool] noring (false)
       *   If enabled, a non-ringing kernel will be used for supersampling
       *   Doesn't apply to nnedi3 supersampling
   + [string] matrix (709 if input height >= 600, otherwise 601)
       *   Color matrix to be used for conversions between YUV and RGB
   + [bool] tv_range (true)
       *   Specifies the range of the pixel values of the input and output clips
   + [string] cplace (MPEG2)
       *   Chroma siting of the clip to be processed (refer to the Dither docs for more information)
   + [bool/int] mask (simple if no mclip is specified, otherwise false)
       *   Specifies whether or not the script should build an edge mask for masked antialiasing
       *   Can be either True/False or one of the following mask presets: simple, simple-cmb, precise-cmb
       *   The mask is also used as a prescreener for eedi3 so using one will yield a considerable speedup
   + [clip] mclip (Undefined)
      *   Allows you to bring your own mask instead of relying on haa's internal masking
      *   The mask must be 8-bit YUV and of the same resolution as the source clip
      *   If you supply an Y8 mask, haa will automatically used its Y plane for masking all processed source planes
      *   For other color spaces the chroma subsampling must match that of the input clip (use YV24 for RGB input)
          and haa will mask all planes separatly
   + [int] mthr (30)
      *   Binarization threshold for the internal masking. 
      *   Decrease if the masking misses aliased edges, increase if the mask includes pristine details and flat areas
   + [bool] show (false)
      *   If enabled, visualizes the mask instead of running the antialiasing
      *   Useful for tweaking mask and mthr
   + [bool/int] sa_aa (true for aa methods that include sangnom, otherwise false) sa_aac (false)  
      *   Enables/Disables Sangnom2 based antialiasing on the luma and chroma channels
      *   Enabled if the supplied is an integer, which will be passed on as aa/aac parameters to Sangnom2 
   + [int] threads
      *   Number of threads to be distributed to eedi3/nnedi3/Sangnom
   
*/

function haa(clip c, string "aa", string "ss", float "ssf", bool "lsb_in", bool "lsb_out", int "y", int "u", int "v", string "fmt_in", string "fmt_out", int "dither",
\                float "ee_fac", float "ee_alpha", float "ee_beta", float "ee_gamma", int "ee_nrad", int "ee_mdis", bool "ee_hp",
\                float "sharp",  string "kernel_d", bool "noring", string "matrix", bool "tv_range", string "cplace",
\                val "mask", clip "mclip", int "mthr", bool "show", val "sa_aa", val "sa_aac", int "threads")
{
    aa_lst = "eedi3||eedi3+sangnom2||sangnom2"
    rsz_lst = "bicubic||catmull-rom||hermite||mitchell-netravali||robidoux||softcubic||blackman||lanczos||lanczos4||sinc||" 
           \ +"blackmanminlobe||box||rect||spline||spline144||spline16||spline36||spline64||bilinear||point"
    ss_lst = "nnedi3"
    
    aa = Default(aa, "eedi3")
    ss = Default(ss, "Spline36")
    kernel_d = Default(kernel_d, "Spline36")
    ssf = Default(ssf, Select(LuIsEq(aa, aa_lst, true), 1.0, 1.0, 2.0))
    ee_fac = Default(ee_fac, 2.0)
    fmt_in = Default(fmt_in, c.PixelType)
    fmt_out = Default(fmt_out, fmt_in)
    lsb_in = FmtIsRGB(fmt_in) ? false : Default(lsb_in, false)
    lsb_out = Default(lsb_out, lsb_in)
    dither = Default(dither, 6)
    show = Default(show, false)
    # todo: add assert for y/u/v
    y = Default(y, 3)
    u = Default(u, 2)
    v = Default(v, U)
    y_aa = y.LuIsEq("3||4") ? 3 : 1 
    u_aa = u.LuIsEq("3||4") && (!c.IsY8 || FmtIsRGB(fmt_in)) ? 3 : 1
    v_aa = v.LuIsEq("3||4") && (!c.IsY8 || FmtIsRGB(fmt_in)) ? 3 : 1
    y_msk = (y==3) ? 3 : 1
    u_msk = (u==3 && u_aa==3) ? 3 : 1
    v_msk = (v==3 && v_aa==3) ? 3 : 1   
    y_lg = (y == 3) ? 4 : y
    u_lg = (u == 3) ? 4 : u
    v_lg = (v == 3) ? 4 : v
    #~ y_in = (y == 4) ? 2 : (y ==2) ? 3 : y     # Dither y/u/v == 2 -> copy msb
    #~ u_in = (u == 4) ? 2 : (u ==2) ? 3 : u
    #~ v_in = (v == 4) ? 2 : (v ==2) ? 3 : v
    mthr = Default(mthr, 30)
    proc_chroma = u==3 || v==3
    ee_fmt_out = (!proc_chroma) ? "Y8" : FmtIsYUV(fmt_out) ? fmt_out : "YV24"
    noring = Default(noring, false) # Todo: make noring a val and make it work like in Resize8, write wrapper for dither_resize16

    sw = c.Width
    sh = (lsb_in) ? c.Height/2 : c.Height
    ssw = int(round(sw*ssf/4.0)*4)
    ssh = int(round(sh*ssf/4.0)*4) 
    ee_ssw = int(round(ssw*ee_fac/4.0)*4)
    ee_ssh = int(round(ssh*ee_fac/4.0)*4)
    
    Assert(ssf > 0, "eedi3aa: Supersampling factor must be > 0")
    Assert(!((FmtIsYUV(fmt_in) || fmt_in=="RGB48YV12" || fmt_in=="RGB48Y") && c.IsRGB),
         \ "eedi3aa: input format "+fmt_in+" doesn't match detected colorspace "+c.PixelType+".")

    # Handle val types
    Assert(IsString(mask) || IsBool(mask) || !Defined(mask), "eedi3aa: mask must be either True/False or a mask preset") 
    mask_b = IsBool(mask) ? mask : (!Defined(mask) || IsString(mask)) ? true : false
    mask_s = IsString(mask) ? mask : (mask_b) ? "simple" : Undefined
    
    Assert((IsInt(sa_aa) && sa_aa >= 0)  || IsBool(sa_aa)|| !Defined(sa_aa),
         \ "eedi3aa: sa_aa must be either True/False or an integer >= 0")
    sa_aa_b = IsBool(sa_aa) ? sa_aa : (IsInt(sa_aa) || LuIsEq(aa, "eedi3+sangnom2||sangnom2")) ? true : false
    sa_aa_i = IsInt(sa_aa) ? sa_aa : (sa_aa_b) ? 48 : Undefined()    
    
    Assert((IsInt(sa_aac) && sa_aac >= 0)  || IsBool(sa_aac)|| !Defined(sa_aac),
         \ "eedi3aa: sa_aac must be either True/False or an integer >= 0")
    sa_aac_b = IsBool(sa_aac) ? sa_aac : IsInt(sa_aac) ? true : false
    sa_aac_i = IsInt(sa_aac) ? sa_aac : (sa_aac_b) ? Max(sa_aa_i-8,0) : Undefined()
    sa_aa = sa_aa_b || sa_aac_b

    # number of threads
    threads = Default(threads, (sa_aa)?6:4)
    ee_threads = sa_aa ? threads/2 : threads
    sthreads = ee_threads
    
    c_yuv = c
    
    # Convert to YUV
    if (fmt_in == "RGB48YV12") {
        c = RGB48YV12toRGB48Y()
        fmt_in = "RGB48Y"
    }
    
    if (FmtIsRGB(fmt_in) || c.IsRGB()) {
        c_yuv = (fmt_in=="RGB48Y") ? c.Dither_convert_rgb_to_yuv(SelectEvery(3,0), SelectEvery(3,1), SelectEvery(3,2), 
                                 \   matrix, false, tv_range, cplace, lsb=true, output="YV24")   
                                 \ : c.Dither_convert_rgb_to_yuv(matrix=matrix, tv_range=tv_range, cplace=cplace, lsb=true, output="YV24")
        lsb_in = true
        lsb_out = true
    }
    
    c_yuvp = (proc_chroma) ? c_yuv : c_yuv.ConvertToY8()
    
    # Mask
    if (!Defined(mclip) && mask_b) {
       c_yuv8 = (lsb_in) ? c_yuv.DitherPost(mode=-1) : c_yuv
    
       if(mask_s == "simple") {
            mclip = c_yuv8.mt_edge("hprewitt", mthr, mthr, mthr/2, mthr/2, y_msk, u_msk, v_msk).RemoveGrain(17)
                 \ .mt_expand(y=y_msk, u=u_msk, v=v_msk).mt_inflate(y=y_msk, u=u_msk, v=v_msk)
       }
       else if (mask_s == "simple-cmb") {
            mclip = c_yuv8.mt_edge("prewitt", 0, 255, 0, 255, y=3, u=3, v=3).LuMergePlanes("max",1.5,1.5)
                 \ .mt_binarize(mthr).RemoveGrain(17,-1).mt_expand().mt_inflate()
       }
       else if (mask_s == "precise-cmb") {    
            mclip = c_yuv8.mt_edge("hprewitt", 0, 255, 0, 255, y=3, u=3, v=3).LuMergePlanes("max",1.5,1.5,2).mt_expand().mt_inpand()
                 \ .tmaskcleaner(30,30).mt_binarize(mthr).mt_inflate()
       }
       else { Assert(false, "eedi3aa: no mask preset with name '" + String(mask_s) + "' found.") }
    }
    # Mask preview
    if (show) {
        return c_yuv.mt_lut(y=2, u=0, v=0).mt_merge(c_yuv, mclip, u=3, v=3)
    }
    # determine lsb processing
    lsb = lsb_in || lsb_out
    
    # ss
   (ssf != 1.0) ? c_yuvp.LUResize(ssw, ssh, 0, 0, sw, sh, lsb_in, lsb, lsb, ss, matrix, tv_range, noring=noring, cplace=cplace, 
                          \ y=y_aa, u=u_aa, v=v_aa, dither_mode=dither) : c_yuvp
   mclip_ss = (ssf != 1.0) ? mclip.BilinearResize(ssw, ssh) : mclip

                                 
    # eedi3 aa
    if(LuIsEq(aa, "eedi3||eedi3+sangnom2"))
    {
        mclip = mclip.LuMatchCSP(c_yuv, tv_range=false)
        eedi3_resize16(last, ee_ssw, ee_ssh, 0, 0, Undefined, Undefined, kernel_d, Undefined, false, ee_alpha, ee_beta, ee_gamma, ee_nrad, ee_mdis, ee_hp, 
        \              ee_threads, 1.0, sharp, false, Undefined, Undefined, ee_fmt_out, Undefined, Undefined, matrix, tv_range, cplace,
        \               y_aa, u_aa, v_aa, lsb_in, lsb, Undefined, mclip_ss)
    }
    
    # SangNom2 aa
    # todo: allow chroma-only aa
    if (sa_aa)
    {
        proc_chroma_s = sa_aac_b && proc_chroma
        y_s = (sa_aa_b) ? 3 : 4
        u_s = (proc_chroma_s) ? 3 : 4
        v_s = u_s
        
        s_yuv8 = (lsb) ? DitherPost (mode=-1, y=y_aa, u=u_aa, v=v_aa) : last
        s_yxx8 = (proc_chroma_s) ? s_yuv8.ConvertToY8() : s_yuv8
        s_yxx8 = s_yxx8.SangNom2(0, sa_aa_i, sa_aac_i, sthreads).TurnRight()
                     \ .SangNom2(0, sa_aa_i, sa_aac_i, sthreads).TurnLeft()
        s_yxx16 = s_yxx8.Lu8To16(tv_range, true, proc_chroma_s)
        (lsb) ? last.LuMatchCSP(s_yuv8).Dither_limit_dif16(s_yxx16, thr=1.0, elast=2.0, y=y_s, u=u_s, v=v_s) : s_yxx8
    }
    

    # Downscale
    LUResize(sw, sh, lsb_in=lsb, lsb_out=lsb_out, kernel=kernel_d, tv_range=tv_range, noring=false,
           \ cplace=cplace, dither_mode=dither, y=y_aa, u=u_aa, v=v_aa)

    # Merge
    if (IsClip(mclip)) {
       if (FmtIsYUV(fmt_in) && (fmt_in != fmt_out)) {
            c_yuvm = c_yuv.LuMatchCSP(last, matrix, tv_range)
       } else {
            c_yuvm = c_yuv
       }
       
       c_yuvm.LuMerge(last, mclip, y, u, v, Undefined(), lsb_in, lsb_out, lsb_out, false)
       

    } else {
        (y_aa==1 || u_aa==1 || v_aa==1) ? c_yuv.mt_logic(last, "and", y=y_lg, u=u_lg, v=v_lg) : last
    }
    
    # Convert to RGB
    FmtIsRGB(fmt_out) ? Dither_convert_yuv_to_rgb(matrix, false, tv_range, cplace, lsb_in=true, output=fmt_out, mode=dither)
                    \ : last

    function FmtIsYUV(string p) { return (p == "Y8" || p=="YV12" || p=="YV16" || p=="YV24") ? true : false  }
    function FmtIsRGB(string p) { return (p == "RGB24" || p=="RGB32" || p=="RGB48YV12" || p=="RGB48Y") ? true : false }
    function IsEq(int i, int j) { return (i == j) ? true : false } 
}    
