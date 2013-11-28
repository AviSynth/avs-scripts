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
    return Defined(in_depth) ? StackedNto16(in_depth) : last
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

function LuSeparateColumns(int "n")
{
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

function LuMatchCSP(clip c, clip refc, string "matrix", bool "tv_range")
{
    tv_range = Default(tv_range, true)
    matrix = Default(matrix, (c.width >= 600) ? "709" : "601")
    mstr = (tv_range) ? "Rec"+matrix : "PC."+matrix
    csp = refc.PixelType
    return eval("c.ConvertTo" + csp + """(matrix="""" + mstr + """")""")
}