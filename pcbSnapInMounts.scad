//-------------------------------------------------------------
//-- PCB Snap-In Mount Plate (v7)
//-- Correct inner lip cutout + inward slope
//-------------------------------------------------------------

//-- ===== Parameters (mm) =====
pcbWidth        = 60;
pcbLength       = 100;
pcbThickness    = 1.6;

snapInThickness = 3;          //-- XY thickness of wall
snapInHeight    = 12;         //-- Z height above plate
plateThickness  = 2;

snapInSlope     = 45;         //-- degrees, 30..60 typical
snapInWidth     = 6;          //-- width of each snap along edge

//-- Snap-in positions (0 disables)
snapInPosTop    = pcbWidth  / 2;
snapInPosBottom = pcbWidth  / 2;
snapInPosLeft   = pcbLength / 2;
snapInPosRight  = pcbLength / 2;

showDebug = 1;                //-- 1 = debug colors, 0 = final solid

//-------------------------------------------------------------
//-- Helpers
//-------------------------------------------------------------
function clamp(v,a,b) = max(a, min(b, v));
function drop_at_angle(thk, ang_deg, max_drop) = clamp(tan(ang_deg) * thk, 0, max_drop);

//-------------------------------------------------------------
//-- Green cutter: slope from outer top → inner lower top
//-------------------------------------------------------------
module cutSlopeAtTop(runLen)
{
    H = snapInHeight;
    T = snapInThickness;
    D = drop_at_angle(T, snapInSlope, H);

    v = [
        [-runLen/2, 0, H - D],   // inner top (X-)
        [ runLen/2, 0, H - D],   // inner top (X+)
        [-runLen/2, T, H],       // outer top (X-)
        [ runLen/2, T, H],       // outer top (X+)
        [-runLen/2, 0, H*2],     // extend top to cut properly
        [ runLen/2, 0, H*2],
        [-runLen/2, T, H*2],
        [ runLen/2, T, H*2]
    ];

    faces = [
        [0,1,3,2],
        [2,3,7,6],
        [0,4,5,1],
        [0,2,6,4],
        [1,5,7,3],
        [4,6,7,5]
    ];

    color([0,1,0,0.5]) polyhedron(points=v, faces=faces, convexity=10);
}

//-------------------------------------------------------------
//-- Blue lip CUTTER: makes a recess for PCB edge to snap in
//-------------------------------------------------------------
module lipCutter(runLen)
{
    lipDepth  = pcbThickness * 1.2;        //-- deeper than PCB for clearance
    lipHeight = pcbThickness * 1.2;        //-- vertical size of notch
    //lipZ      = snapInHeight - (2.5 * pcbThickness); //-- vertical position below top
    lipZ      = snapInHeight - (3.2 * pcbThickness); //-- vertical position below top

    color("blue")
    translate([ -runLen/2, -lipDepth, lipZ ])
        //cube([ runLen, lipDepth + snapInThickness, lipHeight ]);
        cube([ runLen, lipDepth+(snapInThickness/2), lipHeight ]);
}

//-------------------------------------------------------------
//-- Red wall before subtracting slope + lip
//-------------------------------------------------------------
module wallBlock(runLen)
{
    color("red")
    translate([ -runLen/2, 0, 0 ])
        cube([ runLen, snapInThickness, snapInHeight ]);
}

//-------------------------------------------------------------
//-- Full Snap-In Mount
//-------------------------------------------------------------
module snapInMount(runLen)
{
    if (showDebug)
    {
        wallBlock(runLen);
        cutSlopeAtTop(runLen);
        lipCutter(runLen);
    }
    else
    {
        difference()
        {
            wallBlock(runLen);
            cutSlopeAtTop(runLen);
            lipCutter(runLen);
        }
    }
}

//-------------------------------------------------------------
//-- Snap placement helpers
//-------------------------------------------------------------
module placeTop(pos, runLen)
{
    if (pos != 0)
        translate([ clamp(pos, runLen/2, pcbWidth - runLen/2) - pcbWidth/2,
                    pcbLength/2, plateThickness ])
            snapInMount(runLen);
}

module placeBottom(pos, runLen)
{
    if (pos != 0)
        translate([ clamp(pos, runLen/2, pcbWidth - runLen/2) - pcbWidth/2,
                   -pcbLength/2, plateThickness ])
            rotate([0,0,180]) snapInMount(runLen);
}

module placeLeft(pos, runLen)
{
    if (pos != 0)
        translate([ -pcbWidth/2,
                    clamp(pos, runLen/2, pcbLength - runLen/2) - pcbLength/2,
                    plateThickness ])
            rotate([0,0,90]) snapInMount(runLen);
}

module placeRight(pos, runLen)
{
    if (pos != 0)
        translate([  pcbWidth/2,
                    clamp(pos, runLen/2, pcbLength - runLen/2) - pcbLength/2,
                    plateThickness ])
            rotate([0,0,-90]) snapInMount(runLen);
}

//-------------------------------------------------------------
//-- Main Assembly
//-------------------------------------------------------------
module pcbSnapInPlate()
{
    plateWidth  = pcbWidth  + 2*snapInThickness;
    plateLength = pcbLength + 2*snapInThickness;

    //-- Base plate
    color("gold")
    translate([ -plateWidth/2, -plateLength/2, 0 ])
        cube([ plateWidth, plateLength, plateThickness ]);

    //-- Mounts
    placeTop(   snapInPosTop,    min(snapInWidth, pcbWidth)  );
    placeBottom(snapInPosBottom, min(snapInWidth, pcbWidth)  );
    placeLeft(  snapInPosLeft,   min(snapInWidth, pcbLength) );
    placeRight( snapInPosRight,  min(snapInWidth, pcbLength) );
}

//-------------------------------------------------------------
//-- Render
//-------------------------------------------------------------
pcbSnapInPlate();