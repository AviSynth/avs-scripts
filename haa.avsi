/*
haa v0.1
====================

Antialiasing script that works both in 16-bit and 8-bit.
Supports multiple antialiasing and supersampling methods (sangnom2, eedi3, nnedi3, resize kernels), masking and sharpening.

**WIP - everything subject to change without notice**

Requirements:

   * AviSynth+ r1555
   * Dither v1.24.0
   * eedi3 v0.9.2 (Firesledge mod)
   * eedi3_resize v0.1
   * nnedi3 v0.9.4
   * nnedi3_resize16 v3.0
   * Contra-Sharpen mod v3.4
   * SmoothAdjust v2.90
   * Masktools v2.0b1
   * LUtils v0.1
   * Resize8 v1.1
   * RgTools v0.91
   * tmaskcleaner v0.9
   * Sangnom2 v0.35
   * Soothe
   * aWarpSharp2
   * LSFmod 1.9 (and prerequisites)
   * MSharpen 0.9

Input Formats: 

   * Y8/YV12/YV16/YV24 (8-bit or 16-bit stacked)
   * RGB24/RGB32
   * RGB48Y/RGB48YV12
    
    
Parameters:

   + [string] aa (sangnom2)
       *   Antiaaliasing method. Currently supported: eedi3, eedi3+sangnom2, sangnom2 
   + [string] ss (nnedi3)
       *   Supersampling method. Currently supported: all the AVS+/Dither resizing kernels, nnedi3 (tbd)
   + [float] ssf (1.0 for eedi3/eedi3+sangnom2; 2.0 for sangnom2)
       *   Supersampling factor. Increase this to combat artifacts or excessive blurring.
   + [bool] lsb_in (false), lsb_out (lsb_in)
       *   Tells the script whether the input clips are 16-bit stacked or 8 bit
       *   Setting either of these parameters to true will enable lsb processing (which results in a speed hit)
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
   + [bool/string] sharp (false)
       *   Sharpening applied to the supersampled clip after antialiasing
       *   Can be True/False or one of the following methods:
           *    "csmod" : contra sharpening (Default if set to true)
           *    "lsfmod" : LSFmod with configurable defaults and strength
           *    "awarpsharp2" : aWarpSharp2 applied at supersampling resolution (ssf*ee_fac)
           *    "awarp4" : aWarpSharp2 applied at 4x source resolution 
   + [int] cs_strength (75)
       *   Contra sharpening strength
   + [int] aw_thresh, aw_blur, aw_depth (4 for awarpsharp2; 2 for awarp4)
       *   Parameters passed to aWarpSharp2 (refer to awarpsharp2 docs for more information)
   + [various] lsf_strength (60), lsf_defaults (fast)
       *   Parameters passed to LSFmod (refer to LSFmod docs for more information)
   + [int] ms_strength (50), ms_threshold
       *   Parameters passed to MSharpen (refer to MSharpen docs for more information)
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
   + [bool/string] mask (simple if no mclip is specified, otherwise false)
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
      *   Number of threads to be used by eedi3/nnedi3/Sangnom2
   
*/

function haa(clip c, string "aa", string "ss", float "ssf", bool "lsb_in", bool "lsb_out", int "y", int "u", int "v", string "fmt_in", string "fmt_out", int "dither",
\            string "kernel_d", bool "noring", string "matrix", bool "tv_range", string "cplace",
\            val "mask", clip "mclip", int "mthr", val "sharp", val "soothe", bool "show", int "threads",
\            float "ee_fac", float "ee_alpha", float "ee_beta", float "ee_gamma", int "ee_nrad", int "ee_mdis", bool "ee_hp",
\            int "nn_nsize", int "nn_nns", int "nn_qual", int "nn_etype", int "nn_pscrn", val "sa_aa", val "sa_aac",
\            int "aw_thresh", int "aw_blur", int "aw_depth", int "cs_strength", int "lsf_strength", string "lsf_defaults", 
\            int "ms_threshold", int "ms_strength")
{
    aa_lst = "eedi3||eedi3+sangnom2||sangnom2"
    rsz_lst = "bicubic||catmull-rom||hermite||mitchell-netravali||robidoux||softcubic||blackman||lanczos||lanczos4||sinc||" 
           \ +"blackmanminlobe||box||rect||spline||spline144||spline16||spline36||spline64||bilinear||point"
    ss_lst = "nnedi3"
    
    aa = Default(aa, "sangnom2")
    ss = Default(ss, "nnedi3")
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
    
    Assert(ssf > 0, "haa: Supersampling factor must be > 0")
    Assert(!((FmtIsYUV(fmt_in) || fmt_in=="RGB48YV12" || fmt_in=="RGB48Y") && c.IsRGB),
         \ "haa: input format "+fmt_in+" doesn't match detected colorspace "+c.PixelType+".")
    
    # Handle val types
    Assert(IsString(mask) || IsBool(mask) || !Defined(mask), "haa: mask must be either True/False or a mask preset") 
    mask_b = IsBool(mask) ? mask : (!Defined(mask) || IsString(mask)) ? true : false
    mask_s = IsString(mask) ? mask : (mask_b) ? "simple" : Undefined 
    
    Assert(IsString(sharp) || IsBool(sharp) || !Defined(sharp), "haa: sharp must be either True/False or a sharpening method") 
    sharp_b = IsBool(sharp) ? sharp :  IsString(sharp) ? true : false
    sharp_s = IsString(sharp) ? sharp : (sharp_b) ? "csmod" : Undefined
    
    Assert((IsInt(sa_aa) && sa_aa >= 0)  || IsBool(sa_aa)|| !Defined(sa_aa),
         \ "haa: sa_aa must be either True/False or an integer >= 0")
    sa_aa_b = IsBool(sa_aa) ? sa_aa : (IsInt(sa_aa) || LuIsEq(aa, "eedi3+sangnom2||sangnom2")) ? true : false
    sa_aa_i = IsInt(sa_aa) ? sa_aa : (sa_aa_b) ? 48 : Undefined()    
    
    Assert((IsInt(sa_aac) && sa_aac >= 0)  || IsBool(sa_aac)|| !Defined(sa_aac),
         \ "haa: sa_aac must be either True/False or an integer >= 0")
    sa_aac_b = IsBool(sa_aac) ? sa_aac : IsInt(sa_aac) ? true : false
    sa_aac_i = IsInt(sa_aac) ? sa_aac : (sa_aac_b) ? Max(sa_aa_i-8,0) : Undefined()
    sa_aa = sa_aa_b || sa_aac_b
    Assert(!(sa_aac_b &&!proc_chroma), "haa: can't do chroma processing in Sangnom2 when chroma planes are not set to process")

    Assert((IsInt(soothe) && 0 <= soothe <= 100) || IsBool(soothe) || !Defined(soothe), 
         \ "haa: soothe must be either True/False or an integer between 0 and 100") 
    soothe_b = IsBool(soothe) ? soothe : IsInt(soothe) ? true : false
    soothe_i = IsInt(soothe) ? soothe : (soothe_b) ? 25 : Undefined
    
    # number of threads
    # todo: optimize
    #~ tfac = min((sa_aa)?1:0 + aa.LuisEq("eedi3||eedi3+sangnom2")?1:0 + (ss=="nnedi3")?1:0, 1)
    threads = Default(threads, 4) 
    ee_threads = threads
    nn_threads = threads
    sa_threads = threads
    
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
       else { Assert(false, "haa: no mask preset with name '" + String(mask_s) + "' found.") }
    }
    # Mask preview
    if (show) {
        return c_yuv.mt_lut(y=2, u=0, v=0).mt_merge(c_yuv, mclip, u=3, v=3)
    }
    # determine lsb processing
    lsb = lsb_in || lsb_out
    
   # ss
   if (ssf != 1.0)
   {
       (ss == "nnedi3") ? c_yuvp.nnedi3_resize16(ssw, ssh, 0, 0, sw, sh, kernel_d, Undefined, false, nn_nsize, nn_nns, 
                                               \ nn_qual, nn_etype, nn_pscrn, nn_threads, 1.0, 0, false, Undefined, 
                                               \ Undefined, ee_fmt_out, Undefined, Undefined, matrix, tv_range, cplace, 
                                               \ y_aa, u_aa, v_aa, lsb_in, lsb, dither)
   \ : (ss.LuIsEq(rsz_lst)) ? c_yuvp.LUResize(ssw, ssh, 0, 0, sw, sh, lsb_in, lsb, lsb, ss, matrix, tv_range, noring=noring, 
                                            \ cplace=cplace, y=y_aa, u=u_aa, v=v_aa, dither_mode=dither)
   \ : Assert(false, "haa: unsupported supersampling method '" + ss + "'.")
   mclip_ss = Defined(mclip) ? mclip.BilinearResize(ssw, ssh) : nop()
   }
   else
   {
        mclip_ss = mclip
        c_yuvp
   }
                                 
    # eedi3 aa
    if(LuIsEq(aa, "eedi3||eedi3+sangnom2"))
    {
        mclip = mclip.LuMatchCSP(c_yuv, tv_range=false)
        eedi3_resize(last, ee_ssw, ee_ssh, 0, 0, Undefined, Undefined, kernel_d, Undefined, false, ee_alpha, ee_beta, ee_gamma, ee_nrad, ee_mdis, ee_hp, 
        \              ee_threads, 1.0, 0, false, Undefined, Undefined, ee_fmt_out, Undefined, Undefined, matrix, tv_range, cplace,
        \               y_aa, u_aa, v_aa, (ssf != 1.0)?lsb:lsb_in, lsb, lsb, Undefined, mclip_ss)
    }
    
    # 8 bit processing
    if (sa_aa || sharp_b)
    {
      c16 = last
      (lsb) ? DitherPost (mode=-1, y=y_aa, u=u_aa, v=v_aa) : last
      (!sa_aac_b) ? ConvertToY8() : nop()
      s_yxx8 = last
    }
    
    # SangNom2 aa
    # todo: allow chroma-only aa
    if (sa_aa)
    {
        s_yxx8 = SangNom2(0, sa_aa_i, sa_aac_i, sa_threads).TurnRight()
              \ .SangNom2(0, sa_aa_i, sa_aac_i, sa_threads).TurnLeft()
        s_yxx8
    }

    # Sharpening
    # todo: add chroma support?
    if (sharp_b)
    {
        if (sharp_s=="csmod") {
            ConvertToYV12()
            CSmod(edgemode=0, chroma=False, ss_w=1.00, ss_h=1.00, preblur=-4, 
                \ Smethod=1, kernel=6, strength=cs_strength, Soothe=-1)
        }
        else if (sharp_s=="awarpsharp2") {
            aw_depth = Default(aw_depth, 4)
            #~ u_w = (proc_chroma) ? 3 : (sa_aac_b) ? 2 : 1
            ConvertToYV12().aWarpSharp2(aw_thresh, aw_blur, Undefined, aw_depth, chroma=1)
        }
        else if (sharp_s=="awarp4") {
            aw_depth = Default(aw_depth, 2)
            #~ u_w = (proc_chroma) ? 3 : (sa_aac_b) ? 2 : 1
            ConvertToYV12()
            s_yxx8 = s_yxx8.Resize8(sw, sh, kernel="Spline36", cplace=cplace)
            c16 = c16.LUResize(sw, sh, lsb_in=lsb, cplace=cplace, tv_range=tv_range)
            # todo: fix inaccurate shift
            aWarp4(Resize8(sw*4, sh*4, 0.375*(width/sw), 0.375*(height/sh), kernel="Spline36", u=false, v=false),
                 \ s_yxx8.ConvertToYV12().aSobel(aw_thresh,1).aBlur(aw_blur, 1, 1), aw_depth, 1)
        }
        else if (sharp_s=="lsfmod") {
            ConvertToYV12()
            lsf_strength = Default(lsf_strength, 60)
            lsf_defaults = Default(lsf_defaults, "fast")
            lsfmod(defaults=lsf_defaults, strength=lsf_strength, ss_x=1, ss_y=1, soothe=false)
        }
        else if (sharp_s=="msharpen") {
            ms_strength=Default(ms_strength, 50)
            msharpen(ms_threshold, ms_strength)
        }
        else { Assert(false, "haa: unsupported sharpen method '" + sharp_s + "'.") }
        
        (soothe_b) ? last.Soothe(s_yxx8, keep=soothe_i) : nop()
    }

    # back to 16 bit
    if (sa_aa || sharp_b)
    {
        (sa_aac_b) ? last.MergeChroma(s_yxx8) : last
        u_s = (sa_aac_b) ? 3 : 2
        (lsb) ? c16.Dither_limit_dif16(last.Lu8To16(tv_range, true, sa_aac_b).LuMatchCSP(c16),
                                     \ thr=1.0, elast=2.0, y=3, u=u_s, v=u_s) : last
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
