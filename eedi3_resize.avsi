/*
eedi3_resize v0.11
====================

eedi3 based resizing script that allows to resize to arbitrary resolutions
while maintaining the correct image center and chroma location.
~~Shamelessly copy-pasted from~~ Based on mawen1250s nnedi3_resize16 v3.0.
Can work both in 8-bit and 16-bit.

Requirements:

   * AviSynth+
   * Dither v1.24.0
   * eedi3 v0.9.2 (Firesledge mod)
   * Contra-Sharpen mod v3.4
   * SmoothAdjust v2.90
   * Masktools 2.0a48
   * LUtils v0.1

Input Formats: Y8/YV12/YV16/YV24 (8-bit or 16-bit stacked)


Parameters:

   + [int] target_width, target_height (source width/height)
       *   Resolution to resize to. Arbitrary resolutions are realized with Dither resizers.
   + [float] src_left (0), src_top (0), src_width(source width), src_height (source height)
       *   Parameters for cropping before resizing
   + [string] kernel_d (Spline36)
       *   Dither resizing kernel used for downscaling
       *   This kernel will also be used when upscaling to arbitrary resolutions that are not exactly multiples of 2
   + [string] kernel_u (Spline64)
       *   Dither resizing kernel used for upscaling
   + [bool] noring (false)
       *   Use non-ringing algorithms for Dither resizers
       *   Enabling this is not recommended, because eedi3_resize will use eedi3 for upscaling edges, anyway
       *   Downscaling with non-ringing resizers may result in blurring and aliasing artifacts
   + [various] alpha (0.4), beta (0.2), gamma (15.0), nrad (3), mdis (35), hp (false), threads (0), vcheck(2),  vthreshmul(1.0), vthresh2(4.0) splinesclip(true)
       *   Parameters passed to eedi3. Refer to the eedi3 docs for more information
       *   vthreshmul multiplies default vthresh0/1 by specified amount
       *   splinesclip determines if a clip upscaled with Dither_resize16_nr is passed to eedi3 as sclip
   + [float] ratiothr (1.125)
       *   When the scaling ratio is below this threshold, eedi3_resize will only use Dither resizers instead of
           the eedi3+Dither_resize16 combo
   + [float] sharp (0)
       *   Strength of contra-sharpening applied to the upscaled clip
       *   A value of 0 disabled sharpening, sensible values are around 50-100
   + [bool] mixed (true)
       *   By default, eedi3_resize uses eedi3 (8-bit) and Dither resizers (16-bit) for edge areas
       *   If this parameter is enabled, the script will only use 16-bit Dither resizers for scaling flat areas to increase precision
       *   Disable this if you want flat areas to be resized using eedi3+Dither_resize16
   + [float] thr (1.0), elast (1.5)
       *   Threshold and elasticity for merging eedi3 output into the clip upscaled with 16-bit Dither resizers
       *   Increase thr to take less pixels from the eedi3 upscaled clip
       *   Increase elast to increase blending between pixels from the eedi3 and Dither upscaled sclips for smoother transitions
   + [string] output (input colorspace)
       *   Output format/color space
       *   May be either one of the AviSynth internal colorspace or one of the Dither formats (RGB48Y, RGB48YV12)
   + [string] curve (linear)
       *   Setting this parameter to any of the following values enables resizing in linear light:
           *   "709", "601", "170", "240", "sRGB", "2020"
       *   refer to the Dither documentation (Dither_y_gamma_to_linear) for more information
   + [float] gcor (1.0)
       *   Gamma correction to be applied when converting to linear light
       *   Requires curve to be something else than "linear"
   + [string] matrix (resolution-based)
       *   Matrix used for YUV->RGB conversion
       *   Defaults to "709" for HD material, "601" for SD material
       *   Refer to the Dither docs (Dither_convert_yuv_to_rgb) for more information
   + [bool] tv_range (true)
       *   Indicates whether the input clip is in TV or PC (full) range
   + [bool] cplace (MPEG2)
       *   Placement of the chroma samples on 4:2:0 YUV formats
       *   Supported values are MPEG2 and MPEG1
   + [int] y (3), u (2), v (u)
       *   Processing options for y/u/v planes:
           *  -x..0 : All the pixels of the plane will be set to -x (disables processing)
           *      1 : Disables processing of the plane (plane will contain garbage)
           *      2 : Copies plane from the input clip (disables processing)
           *      3 : Plane will processed
   + [bool] lsb_in (false), lsb_out (lsb_in)
       *   Tells the script whether the input/output clips are 16-bit stacked or 8 bit
   + [bool] lsb
       *   When enabled, processing will be done in high bitdepth for increased precision and smooth gradients (but at the cost of speed)
       *   When disabled, eedi3_resize will use 8-bit resizers instead of 16-bit resizers
       *   Setting either lsb_in or lsb_out to true will enable high-bitdepth processing by default
       *   High-bitdepth processing is always enabled for RGB output, regardless of what the lsb parameter is set to
   + [int] dither (6)
       * Dither mode for 16->8-bit coversion
       * Refer to the Dither docs (DitherPost) for more information on the various dithering modes
   + [clip] mclip (Undefined)
       *   mask clip to be used as prescreener for eedi3. Depending on the content, it usually results in a significant speed gain

*/

Function eedi3_resize(clip input, int "target_width", int "target_height", float "src_left", float "src_top",
\                        float "src_width", float "src_height", string "kernel_d", string "kernel_u", bool "noring",
\                        float "alpha", float "beta", float "gamma", int "nrad", int "mdis", bool "hp", int "threads",
\                        int "vcheck", float "vthreshmul", float "vthresh2", bool "splinesclip",
\                        float "ratiothr", float "sharp", bool "mixed", float "thr", float "elast",
\                        string "output", string "curve", float "gcor", string "matrix", bool "tv_range", string "cplace",
\                        int "Y", int "U", int "V", bool "lsb_in", bool "lsb_out", bool "lsb", int "dither", clip "mclip")
{
    # Parameters for merging edge&flat upscaled clip
    mixed    = Default(mixed,    True   )
    thr      = Default(thr,      1.0    )
    elast    = Default(elast,    1.5    )

    # Parameters for eedi3
    mclip    = Default(mclip, Undefined())
    alpha    = Default(alpha,      0.4   )
    beta     = Default(beta,       0.2   )
    gamma    = Default(gamma,      15.0  )
    nrad     = Default(nrad,       3     )
    mdis     = Default(mdis,       20    )
    hp       = Default(hp,         false )
    threads  = Default(threads,    0     )

    # Parameters for Dither_resize16
    kernel_d = Default(kernel_d, "Spline36" )
    kernel_u = Default(kernel_u, "Spline64" )
    noring   = Default(noring,   False      )


    # Post-Process
    sharp    = Default(sharp,    0      )

    # Parameters for input/output
    Y        = Default(Y,        3      )
    U        = Default(U,        3      )
    V        = Default(V,        3      )
    lsb_in   = Default(lsb_in,   False  )
    lsb_out  = Default(lsb_out,  lsb_in )
    dither   = Default(dither,   6      )

    sCSP     = input.eedi3_resize_GetCSP()
    Assert(sCSP.LuIsEq("Y8||YV12||YV16||YV24"), "eedi3_resize: only accept Y8, YV12, YV16, YV24 input")

    output   = Default(output,   sCSP   )

    ProcY8     = sCSP == "Y8" || output == "Y8"
    sCSP     = ProcY8 ? "YV24" : sCSP
    OutRGB   = LuIsEq(output, "RGB||RGB24||RGB32||RGB48Y||RGB48YV12")
    oCSP     = OutRGB || ProcY8 ? "YV24" : output
    lsb      = OutRGB ? true : Default(lsb, lsb_in || lsb_out)

    Y        = min(Y, 4)
    U        = ProcY8 ? 1 : min(U, 4)
    V        = ProcY8 ? 1 : min(V, 4)
    Yt       = Y == 3 || Y == 4
    Ut       = U == 3 || U == 4
    Vt       = V == 3 || V == 4
    Y31      = Yt ? 3 : 1
    U31      = Ut ? 3 : 1
    V31      = Vt ? 3 : 1
    Y32      = Yt ? 3 : Y
    U32      = Ut ? 3 : U
    V32      = Vt ? 3 : V
    Y21      = Yt ? 2 : Y
    U21      = Ut ? 2 : U
    V21      = Vt ? 2 : V
    Y321     = Y > 1 ? 3 : Y
    U321     = U > 1 ? 3 : U
    V321     = V > 1 ? 3 : V

    sw       = input.Width ()
    sh       = input.Height()
    sh       = lsb_in ? sh/2 : sh
    swc      = sCSP=="YV24" ? sw   : sw/2
    shc      = sCSP=="YV12" ? sh/2 : sh
    HD       = input.LuisHD()

    matrix   = Default(matrix, HD ? "709" : "601")
    curve    = Yt ? Default(curve, "linear") : "linear"
    gcor     = Default(gcor, 1.0)
    tv_range = Default(tv_range, True   )
    cplace   = Default(cplace,   "MPEG2")

    # Parameters for resizer
    ow       = Default(target_width,  sw)
    oh       = Default(target_height, sh)
    owc      = oCSP=="YV24" ? ow   : ow/2
    ohc      = oCSP=="YV12" ? oh/2 : oh
    Assert(!(output=="YV16" && ow!=owc*2), "eedi3_resize: width of YV16 output clip must be MOD2! Is: "+ String(ow))
    Assert(!(output=="YV12" && ow!=owc*2), "eedi3_resize: width of YV12 output clip must be MOD2! Is: "+ String(ow))
    Assert(!(output=="YV12" && oh!=ohc*2), "eedi3_resize: height of YV12 output clip must be MOD2! Is: "+ String(oh))

    src_left    = Default(src_left,   0 )
    src_top     = Default(src_top,    0 )
    src_width   = Default(src_width,  sw)
    src_height  = Default(src_height, sh)


    # Pre-cropping/padding
    prel        = int(src_left/2) * 2
    pret        = int(src_top /2) * 2
    prer        = int((src_width > 0 ? -sw+src_left+src_width : src_width )/2) * 2
    preb        = int((src_height> 0 ? -sh+src_top+src_height : src_height)/2) * 2
    prew        = sw - prel + prer
    preh        = sh - pret + preb

    if (sCSP == "YV24")
    {
        swmod2      = sw  /2*2 == sw
        pwmod2      = prew/2*2 == prew
        wpre        = prew < sw
        prel        = wpre ?          prel            :          0
        prer        = wpre ? pwmod2 ? prer : prer + 1 : swmod2 ? 0 : 1
        prew        = sw - prel + prer
        wpre        = prew < sw || !swmod2
    } else {
        swmod4      = sw  /4*4 == sw
        pwmod4      = prew/4*4 == prew
        wpre        = prew < sw
        prel        = wpre ?          prel            :          0
        prer        = wpre ? pwmod4 ? prer : prer + 2 : swmod4 ? 0 : 2
        prew        = sw - prel + prer
        wpre        = prew < sw || !swmod4
    }

    if (sCSP == "YV12") {
        shmod4      = sh  /4*4 == sh
        phmod4      = preh/4*4 == preh
        hpre        = preh < sh
        pret        = hpre ?          pret            :          0
        preb        = hpre ? phmod4 ? preb : preb + 2 : shmod4 ? 0 : 2
        preh        = sh - pret + preb
        hpre        = preh < sh || !shmod4
    } else {
        shmod2      = sh  /2*2 == sh
        phmod2      = preh/2*2 == preh
        hpre        = preh < sh
        pret        = hpre ?          pret            :          0
        preb        = hpre ? phmod2 ? preb : preb + 1 : shmod2 ? 0 : 1
        preh        = sh - pret + preb
        hpre        = preh < sh || !shmod2
    }

    src_width   = src_width <=0 ? +sw-src_left+src_width : src_width
    src_height  = src_height<=0 ? +sh-src_top+src_height : src_height
    src_left    = wpre ? src_left-prel : src_left
    src_top     = hpre ? src_top -pret : src_top

    src_leftc   = sCSP=="YV24" ? src_left      : src_left  /2.
    src_topc    = sCSP=="YV12" ? src_top   /2. : src_top
    src_widthc  = sCSP=="YV24" ? src_width     : src_width /2.
    src_heightc = sCSP=="YV12" ? src_height/2. : src_height


    # Scale & Shift Calculation
    ratiothr = Default(ratiothr,   1.125)

    yhratio  = float(ow ) / float(src_width  )
    yvratio  = float(oh ) / float(src_height )
    chratio  = float(owc) / float(src_widthc )
    cvratio  = float(ohc) / float(src_heightc)

    enable   = yhratio!=1 || yvratio!=1 || chratio!=1 || cvratio!=1 ||
    \          src_width  !=int(src_width  ) || src_height !=int(src_height ) || src_widthc !=int(src_widthc ) || src_heightc!=int(src_heightc) ||
    \          src_left   !=int(src_left   ) || src_top    !=int(src_top    ) || src_leftc  !=int(src_leftc  ) || src_topc   !=int(src_topc   )

    yhct     = yhratio>ratiothr ? Ceil( log(yhratio/ratiothr) / log(2) ) : 0
    yhrf     = int(Pow(2, yhct))
    yrhratio = yhratio/yhrf
    yvct     = yvratio>ratiothr ? Ceil( log(yvratio/ratiothr) / log(2) ) : 0
    yvrf     = int(Pow(2, yvct))
    yrvratio = yvratio/yvrf

    yhshift  = yhrf>=2 ? 0.5 : 0
    yvshift  = yvrf>=2 ? 0.5 : 0
    yhfix    = -yhshift
    yvfix    = -yvshift

    chct     = chratio>ratiothr ? Ceil( log(chratio/ratiothr) / log(2) ) : 0
    chrf     = int(Pow(2, chct))
    crhratio = chratio/chrf
    cvct     = cvratio>ratiothr ? Ceil( log(cvratio/ratiothr) / log(2) ) : 0
    cvrf     = int(Pow(2, cvct))
    crvratio = cvratio/cvrf

    nonenny  = yhct<=0 && yvct<=0
    nonennc  = chct<=0 && cvct<=0
    nonenn   = nonenny || nonennc

    Ynnt     = Yt&&!nonenny
    Unnt     = Ut&&!nonennc
    Vnnt     = Vt&&!nonennc
    Ynn31    = Ynnt ? 3 : 1
    Unn31    = Unnt ? 3 : 1
    Vnn31    = Vnnt ? 3 : 1
    Ynn      = Yt&&nonenny ? 2 : Y
    Unn      = Ut&&nonennc ? 2 : U
    Vnn      = Vt&&nonennc ? 2 : V

    nnt      = Ynnt || Unnt || Vnnt
    mixed    = !nnt || !enable ? False : mixed


    # calculate chroma placement and center shift
    if (cplace == "MPEG1")
    {
        chshift = (chrf >= 2) ? 0.50 : 0
        cphfixe = 0
        cphfix  = 0
    }
    else if (cplace == "MPEG2")
    {
        if (oCSP == sCSP == "YV24")
        {
            chshift = (chrf >= 2) ? 0.50 : 0
            cphfixe = 0
            cphfix  = 0
        }
        else if (oCSP == "YV24")
        {
            chshift = (chrf >= 2) ? 0.50-chrf/4. : -0.25
            cphfixe = 0
            cphfix  = 0.25
        }
        else if (sCSP == "YV24")
        {
            chshift = (chrf >= 2) ? 0.75 :  0.25
            cphfixe = 0.25-0.25/crhratio
            cphfix  = -0.5
        }
        else
        {
            chshift = (chrf >= 2) ? 0.75-chrf/4. :  0
            cphfixe = 0.25-0.25/crhratio
            cphfix  = 0.25-0.25/chratio
        }
    }
    else { Assert(false, "eedi3_resize: Chroma placement '" + cplace + "' not supported.") }

    cvshift  = (cvrf >=2) ? 0.5 : 0
    chfix    = -chshift
    cvfix    = -cvshift


    # Pre-process

    Assert(!Defined(mclip) || LuIsSameRes(input, mclip, lsb_in, false), "eedi3_resize: mclip doesn't match source clip!")
    input = (wpre || hpre) ? input.LUResize(wpre?prew:sw, hpre?preh:sh, wpre?prel:0, hpre?pret:0, wpre?prew:sw, hpre?preh:sh,
                                         \ kernel="point", lsb_in=lsb_in, lsb_out=lsb_in)
                         \ : input
    mclip = (Defined(mclip) && (wpre || hpre)) ? mclip.LUResize(wpre?prew:sw, hpre?preh:sh, wpre?prel:0, hpre?pret:0, wpre?prew:sw, hpre?preh:sh,
                                         \ kernel="point")
                         \ : mclip
                         

    if (lsb_in) {
        input8 = input.Lu16To8(tv_range, Yt, Ut, Vt, mixed ? -1 : dither)
        input = (lsb) ? input : input8
    }
    else {
        input8 = input
        input = (lsb) ? input.Lu8To16(tv_range, True, True, True) : input
    }

    # eedi3 upscale for edge area
    if (enable && nnt)
    {
        # special case: YV12 input and identical scaling factors for chroma and luma -> eedi3 all planes together
        if(yhct==chct && yvct==cvct && sCSP=="YV12")
        {
            mclip_p = !Defined(mclip) ? Undefined() : (mclip.IsY8) ? YtoUV(mclip, mclip, mclip).ConvertToYV12() : mclip.ConvertToYV12()
            edgenn  = input8.eedi3_resize_rpow2(mclip_p, yvct, yhct, 1, 1, Yt, Ut, Vt, alpha, beta, gamma,
                    \                   nrad, mdis, hp, threads, vcheck, vthreshmul, vthresh2, splinesclip)
            edgennY = (sharp > 0) ? edgenn.CSmod(chroma=False, ss_w=1.00, ss_h=1.00, preblur=-4, Smethod=1, kernel=6, strength=sharp, Soothe=-1)           
                                \ : edgenn
            edgennU = edgennY.UToY8()
            edgennV = edgennY.VToY8()
            edgennY = edgennY.ConvertToY8()
        } else {
            if(Ynnt) {
                mclip_p = Defined(mclip) ? mclip.ConvertToYV12() : Undefined()
                assert(Defined(input8), string(Yt))
                edgennY = input8.ConvertToYV12().eedi3_resize_rpow2(mclip_p, yvct, yhct, 1, 1, Yt, False, False, alpha, beta, gamma,
                        \                                       nrad, mdis, hp, threads, vcheck, vthreshmul, vthresh2, splinesclip)
                edgennY = (sharp >0) ? edgennY.CSmod(chroma=False, ss_w=1.00, ss_h=1.00, preblur=-4, Smethod=1, kernel=6, strength=sharp, Soothe=-1) : edgennY
                edgennY = edgennY.ConvertToY8()
            }
            if (Unnt) {
                mclip_p = !Defined(mclip) ? Undefined() : (mclip.IsY8) ? mclip_p : mclip.UtoY()
                edgennU = input8.UToY().eedi3_resize_rpow2(mclip_p, cvct, chct, 1, 1, Ut, False, False, alpha, beta, gamma,
                        \                                nrad, mdis, hp, threads, vcheck, vthreshmul, vthresh2, splinesclip).ConvertToY8()
            }
            if (Vnnt) {
                mclip_p = !Defined(mclip) ? Undefined() : (mclip.IsY8) ? mclip_p : mclip.VtoY()
                edgennV = input8.VToY().eedi3_resize_rpow2(mclip_p, cvct, chct, 1, 1, Vt, False, False, alpha, beta, gamma,
                        \                                nrad, mdis, hp, threads, vcheck, vthreshmul, vthresh2, splinesclip).ConvertToY8()
            }
        }
    }


    # edge area resize & fix center shift
    #! 8bit in, lsb bit out
    if(enable && nnt)
    {
        edgeY = (Ynnt) ? edgennY.LuResize(ow , oh , src_left *yhrf+yhfix, src_top *yvrf+yvfix, src_width *yhrf, tv_range=tv_range,
                                        \ src_height *yvrf, false, lsb, kernel=kernel_d, y=Y31, u=1, v=1, curve=curve, gcor=gcor)
                     \ : input.LuBlankClip(w=ow, h=oh, pixel_type="Y8", color_yuv=$008080, lsb_in=lsb)

    	edgeU   = (Unnt) ? edgennU.LuResize(owc, ohc, src_leftc*chrf+chfix+cphfixe, src_topc*cvrf+cvfix, tv_range=tv_range,
                                          \ src_widthc*chrf, src_heightc*cvrf, false, lsb, kernel=kernel_d, y=U31, u=1, v=1)
                       \ : input.LuBlankClip(w=owc, h=ohc, pixel_type="Y8", color_yuv=$008080, lsb_in=lsb)

    	edgeV   = (Vnnt) ? edgennV.LuResize(owc, ohc, src_leftc*chrf+chfix+cphfixe, src_topc*cvrf+cvfix, tv_range=tv_range,
                                          \ src_widthc*chrf, src_heightc*cvrf, false, lsb, kernel=kernel_d, y=V31, u=1, v=1)
                       \ : input.LuBlankClip(w=owc, h=ohc, pixel_type="Y8", color_yuv=$008080, lsb_in=lsb)

    	edge  = ProcY8 ? edgeY : YToUV(edgeU, edgeV, edgeY)
    }


    # flat area resize
    if(enable && (mixed || !(Ynnt && Unnt && Vnnt)))
    {
        kernel_y = (yhratio>1||yvratio>1) ? kernel_u : kernel_d
        kernel_c = (chratio>1||cvratio>1) ? kernel_u : kernel_d
        if((yhratio==chratio) && (yvratio==cvratio) && (!mixed || (Ynnt && Unnt && Vnnt)))
        {
            flat = input.LuResize(ow, oh, src_left, src_top, src_width, src_height, lsb, cplace=cplace, noring=noring,
                                \ tv_range=tv_range, kernel=kernel_y, y=Y32, u=U32, v=V32, curve=curve, gcor=gcor)
        }
        else
        {
            flatY = (mixed || !Ynnt) && Yt ? input.ConvertToY8().LuResize(ow, oh, src_left, src_top, src_width, src_height, lsb, noring=noring,
                                                                       \  tv_range=tv_range, kernel=kernel_y, y=Y32, u=1, v=1, curve=curve, gcor=gcor)
                                         \ : input.LuBlankClip(w=ow, h=oh, pixel_type="Y8", color_yuv=$008080, lsb_in=lsb)

            flatU = (mixed || !Unnt) && Ut ? input.UToY8().LuResize(owc, ohc, src_leftc+cphfix, src_topc, src_widthc, src_heightc, lsb, noring=noring,
                                                                    \ tv_range=tv_range, kernel=kernel_c, y=U32, u=1)
                                         \ : input.LuBlankClip(w=owc, h=ohc, pixel_type="Y8", color_yuv=$008080, lsb_in=lsb)

            flatV = (mixed || !Vnnt) && Vt ? input.VToY8().LuResize(owc, ohc, src_leftc+cphfix, src_topc, src_widthc, src_heightc, lsb, noring=noring,
                                                                    \ tv_range=tv_range, kernel=kernel_c, y=U32, u=1)
                                         \ : input.LuBlankClip(w=owc, h=ohc, pixel_type="Y8", color_yuv=$008080, lsb_in=lsb)

            flat  = ProcY8 ? flatY : YToUV(flatU, flatV, flatY)
        }
    }

    # merge & output
    if(enable)
    {
        if (!nnt) {
            final = flat
        }
        else if (mixed) {
            final = flat.LuLimitDif(edge, Undefined, thr, elast, Ynn, Unn, Vnn, lsb, lsb, lsb, tv_range)
        }
        else if ((Ynnt==Unnt && Unnt==Vnnt) || ProcY8) {
            final = edge
        }
        else {
            final = mt_logic(edge, flat, "and", Y=Yt?Ynnt?2:4:1, U=Ut?Unnt?2:4:1, V=Vt?Vnnt?2:4:1)
        }

    } else { # shift only
        final  = input.LUResize(ow, oh, src_left, src_top, src_width, src_height, lsb, kernel="point", y=Y, u=U, v=V)
    }

    final = (ProcY8 && output != "Y8") ? final.LuLut(y=2, u=-128, v=-128, lsb_in=lsb, scale=true) : final
    return final.LuConvCsp(output, matrix, tv_range, lsb, lsb_out, mode=dither)
}


Function eedi3_resize_rpow2(clip input, clip "mclip", int "vct", int "hct", int "vfield", int "hfield",
\                              bool "Y", bool "U", bool "V", float "alpha", float "beta", float "gamma", int "nrad", int "mdis", bool "hp", 
\                              int "threads", int "vcheck", float "vthreshmul", float "vthresh2", bool "splinesclip", bool "honly")
{
    vct      = Default(vct,      1      )
    hct      = Default(hct,      1      )
    vfield   = Default(vfield,   1      )
    hfield   = Default(hfield,   1      )
    Y        = Default(Y,        True   )
    U        = Default(U,        False  )
    V        = Default(V,        False  )
    honly    = Default(honly,    False  )
    mclip    = Default(mclip,    Undefined())
    vthreshmul  = Default(vthreshmul, 1)
    splinesclip = Default(splinesclip, True)
    vthresh0 = 32*vthreshmul
    vthresh1 = 64*vthreshmul
    vthresh2 = Default(vthresh2, 4)
    input

    if(hct >= 1)
    {
        if (honly) {
            mclip = IsClip(mclip) ? mclip.Spline16Resize(last.Width, last.Height) : Undefined()
        } else {
            TurnRight()
            mclip = IsClip(mclip) ? mclip.TurnRight() : Undefined()
        }

        sc = dither_convert_8_to_16().dither_resize16nr(width(),height()*2,src_top = (hfield==0) ? -0.25 : 0.25).ditherpost(mode=-1)
		sclip = splinesclip ? sc : Undefined()
        eedi3(hfield, True, Y, U, V, alpha, beta, gamma, nrad, mdis, hp, mclip=mclip, threads=threads,
        \     vcheck=vcheck, vthresh0=vthresh0, vthresh1=vthresh1, vthresh2=vthresh2, sclip=sclip)

    	hct    = hct - 1
        honly  = hct >= 1
        hfield = 0

        if (!honly) {
            TurnLeft()
            mdis  = min(2*mdis, 40)
            vthresh2=vthresh2*2
            hp    = false
            mclip = IsClip(mclip) ? mclip.TurnLeft() : Undefined()
        }
    }

    if(vct >= 1 && !honly)
    {
        mclip = IsClip(mclip) ? mclip.Spline16Resize(last.Width, last.Height) : Undefined()
        sc = dither_convert_8_to_16().dither_resize16nr(width(),height()*2,src_top = (vfield==0) ? -0.25 : 0.25).ditherpost(mode=-1)
		sclip = splinesclip ? sc : Undefined()
        eedi3(vfield, True, Y, U, V, alpha, beta, gamma, nrad, mdis, hp, mclip=mclip, threads=threads,
        \     vcheck=vcheck, vthresh0=vthresh0, vthresh1=vthresh1, vthresh2=vthresh2, sclip = sclip)

    	vct    = vct - 1
        vfield = 0
    }


    return Y||U||V ? vct <= 0 && hct <= 0 ? last
    \                                     : last.eedi3_resize_rpow2(mclip, vct, hct, vfield, hfield, Y, U, V, alpha, beta, gamma, 
    \                                                               1, mdis, hp,threads, vcheck, vthreshmul, vthresh2, splinesclip, honly)
    \              : input
}


Function eedi3_resize_GetCSP(clip c)
{
    return c.IsPlanar ? c.IsYV12 ? "YV12" :
    \                   c.IsYV16 ? "YV16" :
    \                   c.IsYV24 ? "YV24" : c.GetCSP_Y8_YV411 :
    \      c.IsYUY2   ? "YUY2"   :
    \      c.IsRGB32  ? "RGB32"  :
    \      c.IsRGB24  ? "RGB24"  : "Unknown"


    Function GetCSP_Y8_YV411(clip c) {
        try {
            c.UtoY
            csp = "YV411"
        } catch ( error_msg ) {
        csp = "Y8"
        }
        return csp
    }
}