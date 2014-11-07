# Lazy Utilities v0.12
# too lazy to write a readme

function LuStackedNto16(clip c, int n)
{
    Assert(8 <= n <= 15, "LuStackedNto16: bitdepth should be in range 8-15")
    h = c.Height / 2
    msb = c.Crop(0,0,0,-h)
    lsb = c.Crop(0,h,0,0)
    shamt = string(16-n)
     
    msb16 = (n != 8) ? msb.mt_lutxy(lsb, "x " + shamt + " << y 8 " + shamt + " - >> +", v=3, u=3) : lsb
    lsb16 = (n != 8) ? lsb.mt_lut("x " + shamt + " << 255 &u", v=3, u=3) : msb
    return StackVertical(msb16, lsb16)
}

function LuPlanarToStacked(clip c, int "in_depth")
{
    c.LuSeparateColumns(2)
    lsb = SelectEven()
    msb = SelectOdd()

    StackVertical(msb, lsb)
    return Defined(in_depth) ? LuStackedNto16(in_depth) : last
}

function LuRGB48YV12ToRGB48Y(clip c)
{
    vers = VersionNumber()
    tPref = LuIsFunction("FTurnLeft") ? "F" : ""
    w = c.Width
    h = c.Height
    
    y = (vers < 2.60) ? c : c.ConvertToY8()
    u = (vers < 2.60) ? c.UtoY() : c.UtoY8()
    v = (vers < 2.60) ? c.VtoY() : c.VtoY8()
            
    StackVertical(u,v).SeparateFields()
    StackVertical(y,StackHorizontal(SelectEven(),SelectOdd()))

    m = PointResize(w, h*2).SeparateFields()
    m0 = m.SelectOdd().AssumeFrameBased().SeparateFields()
    m1 = m.SelectEven().AssumeFrameBased().SeparateFields()

    o = m0.SelectOdd()
    q = m0.SelectEven()
    p = m1.SelectEven()
    
    StackHorizontal(o,p,q)
    
    (vers < 2.60) ? eval(tPref+"""TurnRight().AssumeFrameBased().SeparateFields()
                          StackHorizontal(SelectOdd(),SelectEven()) 
                          m = PointResize(h,w*2).AssumeFrameBased().SeparateFields() 
                          m0 = m.SelectEven().AssumeFrameBased().AssumeTFF().SeparateFields().""" + tPref + """TurnLeft()
                          m1 = m.SelectOdd().AssumeFrameBased().AssumeTFF().SeparateFields().""" + tPref + "TurnLeft()") 
                  \: eval(""" SeparateColumns(2) 
                          StackVertical(SelectOdd(),SelectEven())
                          m = PointResize(w*2,h).AssumeFrameBased().SeparateColumns(2)
                          m0 = m.SelectOdd().AssumeFrameBased().SeparateColumns(2)
                          m1 = m.SelectEven().AssumeFrameBased().SeparateColumns(2)""")

    r = m0.SelectEven()
    b = m0.SelectOdd()
    g = m1.SelectOdd()
    
    Interleave(r,g,b)
}

function LuIsFunction(string func)
{
    try { eval(func) }
    catch(error_msg) {
        error = (error_msg.FindStr("there is no function named") != 0) ? true : false
    }
    return !error
}

function LuSeparateColumns(clip c, int "n")
{
    c
    vers = VersionNumber()
    tPref = LuIsFunction("FTurnLeft") ? "F" : ""
    n = Default(n, 2)
    
    (vers < 2.60) ? eval(tPref+"TurnRight().SeparateRows(n)."+tPref+"TurnLeft()")
                \ : SeparateColumns(n)
}

function LuMergePlanes(clip c, string "ymode", float "ufac", float "vfac", int "cinpand", string "cplace")
{
    cplace = Default(cplace, "MPEG2")
    Assert(cplace == "MPEG2" || cplace== "MPEG1", "LuMergePlanes: Chroma placement " + cplace + " not supported") 
    cshift = (cplace=="MPEG2") ? 0.5 : 0
    
    ufac = Default(ufac, 1.0)
    vfac = Default(vfac, 1.0)
    ymode = Default(ymode, "max")
    cinpand = Default(cinpand, 1)
    

    if(!c.IsY8) {
         cy = c.ConvertToY8()
         cu = c.UtoY8()
         cv = c.VtoY8()
    }
    
    if(!c.IsYV24 && !c.IsY8) {
        cu = cu.BilinearResize(cy.Width, cy.Height, src_left=cshift)
        cv = cv.BilinearResize(cy.Width, cy.Height, src_left=cshift)
    }
    if (c.IsY8) {
        return c
    } else {
        chroma = mt_lutxy(cu, cv, "x "+String(ufac)+" * y "+String(vfac)+" * max")
        for(i=cinpand, 0, -1)
        {
            chroma = chroma.mt_inpand()
        }
        return mt_logic(cy, chroma, ymode)
    }
}

function LuIsHD(clip c)
{
    # todo: make it smarter
    return (c.Height >= 600) ? true : false
}

function LuMatchCSP(clip c, clip refc, string "matrix", bool "tv_range")
{
    tv_range = Default(tv_range, true)
    matrix = Default(matrix, c.LuIsHD ? "709" : "601")
    mstr = (tv_range) ? "Rec"+matrix : "PC."+matrix
    csp = refc.PixelType
    return eval("c.ConvertTo" + csp + """(matrix="""" + mstr + """")""")
}

function LuConvCSP(clip c, string csp, string "matrix", bool "tv_range", bool "lsb_in", bool "lsb_out", bool "lsb", 
                 \ string "cplace", string "chromak", float "fh", float "fv", int "taps", float "a1", float "a2", float "a3",
                 \ int "mode", float "ampo", float "ampn", bool "staticnoise", bool "noring", bool "i420_in")
{
    # todo: add rgb48y/rgb48yv12 input support
    csps_rgb_dither = "RGB48YV12||RGB48Y"
    csps_rgb = "RGB||RGB24||RGB32||" + csps_rgb_dither
    csps_yuv = "Y8||YV12||YV16||YV24||YUY2||I420"
    need_dither = LUIsDefined("or", cplace, chromak, fh, fv, taps, a1, a2, a3, noring, mode, ampo, ampn, staticnoise) || csp.LuIsEq(csps_rgb_dither)
    Assert(!need_dither || !Defined(lsb) || !lsb, 
     \ "LUConvCSP: parameter 'lsb' may not be false because one or more of the other parameters supplied" 
     \+"require processing in 16-bit or Dither resizers.")
    tv_range = Default(tv_range, true)
    matrix = Default(matrix, c.LuIsHD ? "709" : "601")
    i420_in = Default(i420_in, false)
    lsb_in = Default(lsb_in, false)
    lsb_out = Default(lsb_out, lsb_in)
    IsYUVtoRGB = (c.IsYUV && csp.LuIsEq(csps_rgb))
    IsRGBtoYUV = (c.IsRGB && csp.LuIsEq(csps_yuv))
    lsb = Default(lsb, IsYUVtoRGB || IsRGBtoYUV || need_dither ? true : false)
    
    mstr = (tv_range) ? "Rec"+matrix : "PC."+matrix
    (i420_in && csp != "I420") ? c.SwapUV : c
    
    Assert(csp.LuIsEq(csps_yuv + "||" + csps_rgb),
         \ "LuConvCSP: Conversion to '" + csp + "' not available.")
     
     if (lsb && IsRGBtoYUV) {
        Dither_convert_yuv_to_rgb(matrix, false, tv_range, cplace, chromak, fh, fv, taps, a1, a2, ae, lsb_in, csp, mode, ampo, ampn, staticnoise, noring)
     }
     else if (lsb && IsRGBtoYUV) {
        Dither_convert_yuv_to_rgb(matrix, False, tv_range, cplace, chromak, fh, fv, taps, a1, a2, a3, lsb_in, csp, mode, amp, ampn, staticnoise, noring)
     }
     else if ((csp != c.PixelType)) {
        eval("ConvertTo" + csp + """(matrix="""" + mstr + """")""")       
     }
     (lsb_in && !lsb_out) ? Lu16To8(tv_range, true, !IsY8, !IsY8, mode) : last
     
    return last
}

Function Lu8To16(clip c, bool "tv_range", bool "Y", bool "U", bool "V")
{
    # shamelessly copy-pasted from nnedi3_resize16 by mawen1250
    
    tv_range = Default(tv_range, True   ) # define if input clip is of tv range(limited range)
    Y        = Default(Y,        True   )
    U        = Default(U,        True   )
    V        = Default(V,        True   )
       
    yExpr    = "0-0;255-65535;65535-65535"
    cExpr    = "0-0;128-32768;255-65535;65535-65535"
    DfExpr   = "0-0;65535-65535"
    Yexpr    = Y ? yExpr : DfExpr
    Uexpr    = U ? cExpr : DfExpr
    Vexpr    = V ? cExpr : DfExpr
      
    if (tv_range) { up = c.Dither_convert_8_to_16() }
    else
    {
        up = StackVertical(c.Dither_gen_null_lsb(), c)
        up = (Y||U||V) ? up.SmoothCurve16(Ycurve=Yexpr, Ucurve=Uexpr, Vcurve=Vexpr, mode=0,
                                        \ limiter=False, TVrange=0, interp=0, dither=-1) : up
        
    } 
    return up
}

Function Lu16To8(clip c, bool "tv_range", bool "Y", bool "U", bool "V", int "dither", int "interp", bool "HQ")
{
    # again shamelessly copy-pasted from nnedi3_resize16 by mawen1250
    
    dither = Default(dither, 6)
    Assert(-1 <= dither <= 8 , "Lu16To8: parameter 'dither' must be between -1 and 8.")
    
    tv_range = Default(tv_range, True   ) # define if input clip is of tv range(limited range)
    interp   = Default( interp,     0   ) # use interp or not for Curve/SmoothCurve16
    HQ       = Default( HQ,     False   ) # enable high quality interpolation (slower)
    Y        = Default(Y,        True   )
    U        = Default(U,        True   )
    V        = Default(V,        True   )
   
    
    if(tv_range)
    {
        c.DitherPost(mode=dither, y=Y?3:1, u=U?3:1, v=V?3:1)
    }
    else if (Y || U || V)
    {
        damnt = Select(dither+1, -1, 25, 50, 50, 50, 50, 50, 50, 50, 50)  # todo: find rougly matching patterns for all modes
    
        yExpr    = "0-0;65535-255"
        cExpr    = "0-0;32768-128;65535-255"
        DfExpr   = "0-0;65535-65535"
        Yexpr    = Y ? yExpr : DfExpr
        Uexpr    = U ? cExpr : DfExpr
        Vexpr    = V ? cExpr : DfExpr
        
        c.SmoothCurve16(Ycurve=Yexpr, Ucurve=Uexpr, Vcurve=Vexpr, mode=0, interp=interp, HQ=HQ, 
                      \ dither=damnt, limiter=False, TVrange=0).Dither_get_lsb()
    }
    else { c.Dither_get_msb() }
    
    return last
}

function LuIsEq(val s, string t, bool "idx")
{
    idx = Default(idx, false)
    if (s.Defined)
    {
        s = !s.IsString ? String(s) : s
        t = (RightStr(t, 2) == "||") ? t : t+"||"
        result = false
        i = -1
        while(!result && FindStr(t,"||") != 0)
        {
            pos = FindStr(t,"||")
            result = result || (s == LeftStr(t, pos-1))
            t = MidStr(t,pos+2)
            i = i+1
        }
        return idx ? (result ? i : -1) : result
    }
    else { return idx ? -2 : false }
}

function LuSubstrAtIdx(string s, int idx, string "sep")
{
    sep = Default(sep, ",")
    s = (RightStr(s, 1) == sep) ? s : s+sep
    for(i=0, idx)
    {
        pos = FindStr(s, sep)
        Assert(pos > 0, "LuSubstringAtIndex: no string at index '" + String(idx) +"'.")
        sstr = LeftStr(s, pos-1)
        s = MidStr(s, pos+StrLen(sep))
    }
    return sstr
}

function LuSubstrCnt(string s, string "sep")
{
    sep = Default(sep, ",")
    s = (RightStr(s, 1) == sep) || (StrLen(s) == 0) ? s : s+sep
    i = 0
    while(Findstr(s, sep) > 0)
    {
        i = i + 1
        pos = FindStr(s, sep)
        s = MidStr(s, pos+StrLen(sep))
    }
    return i
}

function LuReplaceStr(string s, string find, string replace)
{
    if (find != replace)
    {
        while(FindStr(s, find) > 0)
        {
            pos = FindStr(s, find)
            s = LeftStr(s, pos-1) + replace + MidStr(s, pos + StrLen(find))
        }
    }
    return s
}

function LUIsDefined(string mode, val v0, val "v1", val "v2", val "v3", val "v4", val "v5", val "v6", val "v7", val "v8", val "v9", val "v10",
                   \ val "v11", val "v12", val "v13", val "v14", val "v15", val "v16", val "v17", val "v18", val "v19")
{
    Assert(mode == "or" || mode == "and", "LUIsDefined: mode must be 'or' or 'and'")
    
    result = (mode == "and") ? true : false
    mstr   = (mode == "and") ? "&&"  : "||"
    for(i=0, 19) 
    {
        eval("result = result " + mstr + " Defined(v" + String(i) + ")") 
    }
    return result
}


# unfinished, do not use, yet (parameter order will probably change)
function LUResize(clip c, int "width", int "height", float "src_left", float "src_top", float "src_width", float "src_height",
               \  bool "lsb_in", bool "lsb_out", bool "lsb", string "kernel", string "matrix", bool "tv_range", bool "precise", 
               \  bool "noring", float "fh", float "fv", int "taps", float "a1", float "a2", float "a3", int "kovrspl",
               \  bool "cnorm", bool "center", string "cplace",	int "y", int "u", int "v", string "kernel_h", string "kernel_v",
               \  float "totalh", float "totalv", bool "invks", bool "invksh", bool "invksv", int "invkstaps", bool "linear", 
               \  string "curve", float "gcor", int "dither_mode")
{
    center = Default(center, true)
    need_dither = LUIsDefined("or", fh, fv, kovrspl, cnorm, invks, invksh, invksv, linear) || !center ? true : false
    lsb_in = Default(lsb_in, false)
    lsb_out = Default(lsb_out, lsb_in)
    lsb = need_dither ? true : Default(lsb, lsb_in || lsb_out)
    kernel = Default(kernel, "spline36")
    kernel_h = Default(kernel_h, kernel)
    kernel_v = Default(kernel_v, kernel)
    kernel = (kernel_v == kernel_h) ? kernel_h : Undefined
    matrix = Default(matrix, (c.Height >= 600) ? "709" : "601")
    tv_range = Default(tv_range, true)
    precise = Default(precise, true)
    noring = Default(noring, false)
    linear = (Defined(curve) && curve == "linear") ? false :  Default(linear, false)
    curve = Default(curve, "709")
    y = Default(y, 3)
    u = (c.PixelType == "Y8") ? 1 : Default(u, 3)
    v = Default(v, u)
    u_lin = (u==3) ? 2 : (u <= 0) ? u : 1
    v_lin = (v==3) ? 2 : (v <= 0) ? v : 1
    
    sw = c.Width
    sh = lsb_in ? c.Height/2 : c.Height
    ow = Default(width, sw)
    oh = Default(height, sh)
    
    kernel_list = Defined(kernel) ? "kernel" : "kernel_h,kernel_v"
    
    sblock = """
        <KERNEL> = (<KERNEL> == "linear") ? "bilinear" : (<KERNEL> == "gaussian") ? "gauss" 
               \ : (<KERNEL> == "cubic") ? "bicubic" : <KERNEL>
        Assert(!Defined(taps) || !LuIsEq(<KERNEL>, "lanczos||blackman||blackmanminlobe||spline||gauss||sinc"),
             \ "LUResize: kernel '" + <KERNEL> + "' doesn't have a 'taps' parameter")
        Assert(!need_dither || lsb, 
             \ "LUResize: parameter 'lsb' may not be false because one or more of the other parameters supplied" 
             \+"require processing in 16-bit or Dither resizers.")
        
        # set up parameters
        
        ir_cargs = (current_kernel == "kernel_h" ) ? "src_left, 0, src_width, sh"
               \ : (current_kernel == "kernel_v" ) ? "0, src_top, width, src_height"
               \ :                                   "src_left, src_top, src_width, src_height"
        
        idx_bicubic = <KERNEL>.LUIsEq("bicubic||catmull-rom||hermite||mitchell-netravali||robidoux||softcubic", true)
        idx_hastaps = <KERNEL>.LUIsEq("blackman||lanczos||lanczos4||sinc", true)
        idx_dither  = <KERNEL>.LUIsEq("blackmanminlobe||box||rect||spline||spline144", true)
        idx_other   = <KERNEL>.LUIsEq("spline16||spline36||spline64||bilinear||point", true)
        
        if (idx_bicubic >= 0)
        {   
            #                        defaults             catrom    hermite    mitchell   robidoux    softcubic 
            a1 = Select(idx_bicubic, Default(a1, 1/3.),   0.0,      0.0,       1/3.,      0.3782,     Default(a1, 75.) / 100.         )
            a2 = Select(idx_bicubic, Default(a2, 1/3.),   0.5,      0.0,       1/3.,      0.3109,     Default(a2, (1-a1)*100) / 100.  )
            <KERNEL> = "bicubic"
            ir_args_<KERNEL> = "a1, a2, " + ir_cargs
        }
        else if(idx_hastaps >= 0)
        {
            #                                        blackman   lanczos   lanczos4   sinc
            taps = Default(taps, Select(idx_hastaps, 4,         3,        4,         4    ))
            <KERNEL> = (<KERNEL> == "lanczos4") ? "lanczos" : <KERNEL>
            ir_args_<KERNEL> = ir_cargs + ", taps"
        }
        else if(idx_dither >= 0)
        {
            #                                        blminlobe   box/rect   spline   spline144
            taps = Default(taps, Select(idx_hastaps, 4,          4, 4,      4,       6         ))
            lsb = true
            
        }
        else if(<KERNEL> == "gauss")
        {
            lsb = Defined(taps) ? true : lsb  # taps can only be adjusted in dither
            ir_args_<KERNEL> = ir_cargs + ", a1"
        }
        else if (idx_other >= 0)
        {
            ir_args_<KERNEL> = ir_cargs
        }
        else if (FindStr(<KERNEL>, "impulse") > 0)
        {
            lsb = true
        }
        else { Assert(false, "LUResize: kernel '" + <KERNEL> +"' is not supported") }
    """
        
    for(i=0, LuSubstrCnt(kernel_list)-1)
    {
        current_kernel = LuSubstrAtIdx(kernel_list, i)
        eval(LuReplaceStr(sblock, "<KERNEL>", LuSubstrAtIdx(kernel_list, i)))
    }

    # resize
    if(lsb)
    {
        rsz = noring ? "Dither_resize16nr" : "Dither_resize16"
        c16 = lsb_in ? c : c.LU8To16(tv_range, y==3, u==3, v==3)
        c16 = linear ? c16.Dither_y_gamma_to_linear(tv_range, tv_range, curve, u, v, gcor) : c16
        eval(rsz+"""(c16, ow, oh, src_left, src_top, src_width, src_height, kernel, fh, fv, taps, a1, a2, a3,
                      \ kovrspl, cnorm, center, cplace, y, u, v, kernel_h, kernel_v, totalh, totalv,
                      \ invks, invksh, invkstaps)""")
        linear ? last.Dither_y_linear_to_gamma(tv_range, tv_range, curve, u, v, gcor) : last
        lsb_out ? last : LU16To8(tv_range, y==3, u==3, v==3, dither_mode)
    }
    else 
    {
        c8 = lsb_in ? c.LU16To8(tv_range, y==3, u==3, v==3, dither_mode) : c
        if (precise && !Defined(kernel)) {
            c8.Resize8(ow, sh, src_left, 0, src_width, sh, kernel_h, Undefined, a1, a2, 
                     \ Undefined, Undefined, noring, Undefined, cplace, y==3, u==3, v==3, false)
            Resize8(ow, oh, 0, src_top, width, src_height, kernel_v, Undefined, a1, a2, 
                     \ Undefined, Undefined, noring, Undefined, cplace, y==3, u==3, v==3, false)
        }
        else if (precise)
        {
            c8.Resize8(ow, oh, src_left, src_top, src_width, src_height, kernel, Undefined, a1, a2, 
                     \ Undefined, Undefined, noring, Undefined, cplace, y==3, u==3, v==3, false)
        }
        else if (!Defined(kernel))
        {
            Eval("c8." + kernel_h + "Resize(ow, sh, " + ir_args_kernel_h +")")
            Eval(kernel_v + "Resize(ow, oh, " + ir_args_kernel_v +")")
        }
        else
        {
            Eval("c8." + kernel + "Resize(ow, oh, " + ir_args_kernel +")")
        }
        
        lsb_out ? LU8To16(tv_range, y==3, u==3, v==3) : last
    }
}


function LuMerge(clip c1, clip c2, clip mask, int "y", int "u", int "v", bool "luma", bool "lsb_in1", bool "lsb_in2", 
               \ bool "lsb_out", bool "lsb_mask", bool "lsb", bool "scale", bool "tv_range")
{
    # todo: hadle offX, off, w, h
    lsb_in1 = Default(lsb_in1, false)
    lsb_in2 = Default(lsb_in2, false)
    lsb_out = Default(lsb_out, lsb_in1 || lsb_in2)
    lsb_mask = Default(lsb_mask, false)
    lsb = lsb_mask ? true : Default(lsb, lsb_out)
    tv_range = Default(tv_range, true)
    y = Default(y,3)
    u = Default(u,(Defined(luma)&&luma)?3:2)
    v = Default(v,u)
    luma = Default(luma, (u!=3 && v!=3) ? false : (mask.IsY8) ? true : false)
    scale = Default(scale, (y < -255 || u < -255 || v < -255) ? false : true)
    # use luma plane of a Y8 mask clip for chroma channels by default if the chroma planes are going to be processed
    Assert(!(mask.IsY8 && !luma && (u==3 || v==3)), "LuMerge: mask is clip is missing the chroma plane(s) required "
                                                 \ +"to process the chroma plane(s) of the input clips." )
    
    if((c1.IsY8 && !c2.IsY8) || (!c1.IsY8 && c2.IsY8))
    {
        if(c1.IsY8 && !LuIsEq(u,"3|2") && !LuIsEq(v,"3|2"))
        { c1 = c1.LuMatchCSP(c2) }
        else if (c2.IsY8 && !LuIsEq(u,"3|4") && !LuIsEq(v,"3|4"))
        { c2 = c2.LuMatchCSP(c1) }
        else
        { 
            Assert(false, "LuMerge: can't merge Y8 clip with YV12/YV16/YV24 clip if chroma planes are to be processed " 
                       \ +"or copied from the Y8 clip.")
        }
        
    }
    
    if(lsb && mask.IsY8 && !c1.IsY8 && ((u!=3 && v!=3) || luma==true)) {
        mask = mask.LuMatchCSP(c1)
    }
    
    if(scale && lsb)
    {
        y = (y < 0) ? y * 256 : y
        u = (u < 0) ? u * 256 : u
        v = (v < 0) ? v * 256 : v
    }
    
    if(lsb) {
        c1_16 = (lsb_in1) ? c1 : c1.LU8To16(tv_range, LUIsEq(y,"2||3"), LUIsEq(u,"2||3"), LUIsEq(v,"2||3"))
        c2_16 = (lsb_in2) ? c2 : c2.LU8To16(tv_range, LUIsEq(y,"4||3"), LUIsEq(u,"4||3"), LUIsEq(4,"4||3"))
        
        (lsb_mask) ? c1_16.Dither_merge16(c2_16, mask, y, u, v, luma) : c1_16.Dither_merge16_8(c2_16, mask, luma, y, u, v)
        (lsb_out) ? last : last.Lu16To8(tv_range, y!=1, u!=1, v!=1)
    } else {
        c1_8 = (lsb_in1) ? c1.Lu16To8(tv_range, LUIsEq(y,"2||3"), LUIsEq(u,"2||3"), LUIsEq(v,"2||3")) : c1
        c2_8 = (lsb_in2) ? c2.Lu16To8(tv_range, LUIsEq(y,"4||3"), LUIsEq(u,"4||3"), LUIsEq(v,"4||3")) : c2
        
        c1_8.mt_merge(c2_8, mask, luma, y, u, v)
    }
    
    return last
}

function LuLut(c, string "expr", string "yexpr", string "uexpr", string "vexpr", int "y", int "u", int "v", bool "lsb_in", bool "scale")
{
    lsb_in = Default(lsb_in, false)
    scale = Default(scale, (y < -255 || u < -255 || v < -255) ? false : true)
    y = Default(y,3)
    u = Default(u,3)
    v = Default(v,u)
    
    if(scale && lsb_in)
    {
        y = (y < 0) ? y * 256 : y
        u = (u < 0) ? u * 256 : u
        v = (v < 0) ? v * 256 : v
    
        expr_list = Defined(expr) ? "expr," : "" + Defined(yexpr) ? "yexpr," : "" 
                \ + Defined(uexpr) ? "uexpr," : "" + Defined(vexpr) ? "vexpr" : ""            
        eblock = """<EXPR> = <EXPR> + " 256 *" """
        
        for(i=0, LuSubstrCnt(expr_list)-1)
        {
            current_expr = LuSubstrAtIdx(expr_list, i)
            eval(LuReplaceStr(eblock, "<EXPR>", LuSubstrAtIdx(expr_list, i)))
        }
    }
    
    (lsb_in) ? c.Dither_lut16(expr, yexpr, uexpr, vexpr, y, u, v) 
           \ : c.mt_lut(expr, yexpr, uexpr, vexpr, y, u, v) 
           
    return last
    
}

function LuLimitDif(clip  flt, clip src, clip  "ref", float "thr", float "elast", int "y", int "u", int "v",
                  \ bool "lsb_in1", bool "lsb_in2", bool "lsb_out", bool "tv_range")
{
    lsb_in1 = Default(lsb_in1, false)
    lsb_in2 = Default(lsb_in2, lsb_in1)
    lsb_out = Default(lsb_out, lsb_in1||lsb_in2)
    y = Default(y, 3)
    u = Default(u, 3)
    v = Default(v, u)
    
    flt = (lsb_in1) ? flt : flt.Lu8To16(tv_range, LuIsEq(y,"2||3"), LuIsEq(u,"2||3"), LuIsEq(v,"2||3"))
    src = (lsb_in2) ? src : src.Lu8To16(tv_range, LuIsEq(y,"4||3"), LuIsEq(u,"4||3"), LuIsEq(v,"4||3"))
    
    flt.Dither_limit_dif16(src, ref, thr, elast, y, u, v)
   
    return (lsb_out) ? last : last.Lu16To8(tv_range, y!=1, u!=1, v!=1)

}

function LuBlankClip(clip c, int "length", int "w", int "h", string "pixel_type", int "fps", int "fps_denominator",
                   \ int "color", int "color_yuv", bool "lsb_in")
{
    lsb_in = Default(lsb_in, false)
    w = Default(w, c.Width)
    h = Default(h, c.Height/2)
    h = (lsb_in) ? h*2 : h
    
    return c.BlankClip(length, w, h, pixel_type, fps, fps_denominator, color=color, color_yuv=color_yuv)
}

# todo: add nnedi/eedi parameters maybe
function LuEdi(clip c, string type, bool "ver", bool "hor", int "field", bool "avgfields", 
             \ int "y", int "u", int "v", bool "lsb", bool "tv_range")
{
    y = Default(y, 3)
    u = Default(u, 2)
    v = Default(v, u)
    lsb = Default(lsb, false)
    ver = Default(ver, true)
    hor = Default(hor, false)
    avgfields = Default(avgfields, false)
    yb = y>=3
    ub = u>=3
    vb = v>=3

    c8 = lsb ? c.Lu16To8(tv_range, yb, ub, vb, -1) : c

    plane_list = yb || (c.PixelType == "YV12" && (ub||vb)) ?"y,":""
    plane_list = plane_list + (LuIsEq(c.PixelType, "YV16||YV24") ? (ub?"u,":"") + (vb?"v,":"") : "")

    if (!(yb||ub||vb)) {
        return c
    }
    sblock = """
        hor_<PLANE> = hor
        if (current_plane.LuIsEq("u||v")) {
            c8.<PLANE>toY().ConvertToYV12()
            xb = false
        } else {
            c8.ConvertToYV12()
            xb = true 
        }
       
        if (!(((ver?1:0)+(hor?1:0))==0)) #temporary hack until loops in avs+ are fixed
        {
        for (cnt=(ver?1:0)+(hor?1:0), 1, -1)
        {
            hor_<PLANE> ? TurnLeft() : nop()    
              (type == "nnedi3") ? nnedi3(field, false, yb||!xb, ub&&xb, vb&&xb) :
            \ (type == "nnedi2") ? nnedi2(field, false, yb||!xb, ub&&xb, vb&&xb) :
            \ (type == "eedi3") ? eedi3(field, false, yb||!xb, ub&&xb, vb&&xb) :
            \ Assert(false, "LuEdi: unsupported edi type")
            
            avgfields ? mt_average(SelectEven(), SelectOdd(), yb||!xb?3:1, ub&&xb?3:1, vb&&xb?3:1) : nop()
            hor_<PLANE> ? TurnRight() : nop()
            hor_<PLANE> = false
        }
        }
        c8_<PLANE> = last
    """        

    for(i=0, LuSubstrCnt(plane_list)-1)
    {
        current_plane = LuSubstrAtIdx(plane_list, i)
        eval(LuReplaceStr(sblock, "<PLANE>", LuSubstrAtIdx(plane_list, i)))
    }
    
    LuIsEq(c.PixelType, "YV16||YV24") && (ub || vb) ? YtoUV(ub?c8_u:c8.UtoY8(), vb?c8_v:c8.VtoY8(),yb?c8_y:c8) : c8_y.LuMatchCSP(c8)
    
    if (lsb) {
    Lu8To16(tv_range, y>=3, u>=3, v>=3)
    c.Dither_limit_dif16 (last, thr=1.0, elast=2.0)
    }
    
    return c.mt_logic(last, "and", y=y>=3?4:y, u=u>=3?4:u, v=v>=3?4:v)
}

function LuIsSameRes(clip c1, clip c2, bool "lsb1", bool "lsb2")
{
    lsb1 = Default(lsb1, false)
    lsb2 = Default(lsb2, false)
    w1 = c1.Width
    w2 = c2.Width
    h1 = lsb1 ? c1.Height/2 : c1.Height
    h2 = lsb2 ? c2.Height/2 : c2.Height
    
    return w1==w2 && h1==h2
}