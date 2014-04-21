function quickTraceMask(clip c, string "colors", int "tolerance", int "lumalow", int "lumahigh", string "mode", float "ss", bool "aa", int "expand", bool "show", bool "bt601")
{
    mode = Default(mode, "and")
    ss = Default(ss, 2.0)
    aa = Default(aa, true)
    expand = Default(expand, 3)
    bt601 = Default(bt601, false)
    lumalow = Default(lumalow, 0)
    lumahigh=Default(lumahigh, 255)
    show = Default(show, false)
    
    sw = c.Width sh = c.Height
    ssw = int(round(sw*ss/4.0)*4)  ssh = int(round(sh*ss/4.0)*4)
    
    useluma = (lumalow > 0 || lumahigh < 255) ? true : false
    usecolor = Defined(colors) && colors!=""

    c
    if(ss != 1.0) { Spline36Resize(ssw, ssh) }
    if(usecolor) { cmask = tcolormask(colors, tolerance, bt601).ConvertToY8(bt601 ? "Rec601" : "Rec709") }
    lmask = useluma ? ConvertToY8(bt601 ? "Rec601" : "Rec709").mt_lut("x " + String(lumalow) + " >= x " + String(lumahigh) + " <= & 0 255 ?",y=3,u=1,v=1) 
                           \: (mode.LuIsEq("min||and")) ? last.BlankClip(pixel_type = "Y8", color_yuv=0) : last.BlankClip(pixel_type = "Y8", color_yuv=$FFFFFF)
    
    usecolor ? useluma ? mt_logic(cmask, lmask, mode) : cmask : lmask
    if(expand > 0) {mt_expand_multi(sw=expand, sh=expand)}
    else if(expand < 0) {mt_inpand_multi(sw=expand, sh=inpand)}
    if(ss != 1.0) { Spline36Resize(sw, sh) }
    if(aa) { HiAA(aa="sangnom2", preaa=True) }
    return show ? c.mt_merge(c.mt_lut(y=2, u=0, v=0), last, u=3, v=3, luma=true) : mt_invert()
}