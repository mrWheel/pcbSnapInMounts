//-------------------------------------------------------------
//-- PCB Snap-In Mount Plate (v7)
//-- Correct inner lip cutout + inward slope
//-------------------------------------------------------------

//-- ===== Parameters (mm) =====
pcbWidth        = 30.5;
pcbLength       = 31.0;
pcbThickness    = 1.6;
pcbClearance    = 0.15;  //-- small fit tolerance, adjust if PCB feels too tight

snapInThickness = 4;          //-- XY thickness of wall
snapInHeight    = 12;         //-- Z height above plate

snapInSlope     = 45;         //-- degrees, 30..60 typical
snapInWidth     = 4;          //-- width of each snap along edge

//-- Snap-in positions (0 disables)
snapInPosTop    = pcbWidth  / 2;
snapInPosBottom = pcbWidth  / 2;
snapInPosLeft   = 8; //pcbLength / 2;
snapInPosRight  = pcbLength / 2;

plateThickness  = 2;
plateHole1Pos   = [pcbWidth/5, pcbLength/2, 3];  //-- X-ax, Y-ax, diameter M3
plateHole2Pos   = [pcbWidth-(pcbWidth/5), pcbLength/2, 3];        //-- X-ax, Y-ax, diameter M3
plateHole3Pos   = [0, 0, 3];       //-- X-ax, Y-ax, diameter M3
plateHole4Pos   = [0, 0, 3];       //-- X-ax, Y-ax, diameter M3

showDebug = 0;                //-- 1 = debug colors, 0 = final solid

//-------------------------------------------------------------
//-- Helpers
//-------------------------------------------------------------
function clamp(v,a,b) = max(a, min(b, v));
function drop_at_angle(thk, ang_deg, max_drop) = clamp(tan(ang_deg) * thk, 0, max_drop);

//-------------------------------------------------------------
//-- Green cutter: starts LOWER at inner face (H - D)
//-- and reaches H at the outer face, so it always cuts the wall
//-------------------------------------------------------------
module cutSlopeAtTop(runLen)
{
    H = snapInHeight;
    T = snapInThickness;
    D = drop_at_angle(T, snapInSlope, H);   //-- ~T at 45°
    eps = 0.01;                              //-- tiny overlap for robust CSG

    //-- Inner top is lowered by D; outer top stays at H.
    //-- We extend upwards a lot so the difference always removes material.
    v = [
        [-runLen/2, 0, H - D - eps],   // 0 inner top (X-)
        [ runLen/2, 0, H - D - eps],   // 1 inner top (X+)
        [-runLen/2, T, H + eps],       // 2 outer top (X-)
        [ runLen/2, T, H + eps],       // 3 outer top (X+)
        [-runLen/2, 0, H - D + H],     // 4 top extension
        [ runLen/2, 0, H - D + H],     // 5
        [-runLen/2, T, H + H],         // 6
        [ runLen/2, T, H + H]          // 7
    ];

    faces = [
        [0,1,3,2],   //-- sloped rectangle (cutting plane)
        [2,3,7,6],   //-- outer vertical
        [0,4,5,1],   //-- inner vertical
        [0,2,6,4],   //-- side (X-)
        [1,5,7,3],   //-- side (X+)
        [4,6,7,5]    //-- top
    ];

    color([0,1,0,0.5]) polyhedron(points = v, faces = faces, convexity = 10);
}

//-------------------------------------------------------------
//-- Blue lip CUTTER: perfectly matches PCB outer edge
//-------------------------------------------------------------
module lipCutter(runLen)
{
    clearance = 0.2;                       //-- fit clearance
    lipDepth  = pcbThickness + clearance;   //-- depth inward from inner face (Y=0)
    lipHeight = pcbThickness * 1.2;         //-- vertical size of notch
    lipZ      = snapInHeight - (3.2 * pcbThickness); //-- vertical position below top

    color("blue")
    // Inner face at Y=0, extends outward by lipDepth
    translate([ -runLen/2, -lipDepth, lipZ ])
        cube([ runLen, lipDepth, lipHeight ]);
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
//-- Snap placement helpers (with inward offset)
//-- Positions each snap so that its inner wall face overlaps
//-- the PCB edge by half the wall thickness.
//-------------------------------------------------------------

module placeTop(pos, runLen)
{
    if (pos != 0)
        translate([
            //-- X: center position along width
            clamp(pos, runLen/2, pcbWidth - runLen/2) - pcbWidth/2,

            //-- Y: inward offset from top edge
            (pcbLength / 2) - (snapInThickness / 2),

            //-- Z: on top of the base plate
            plateThickness
        ])
            snapInMount(runLen);
}

module placeBottom(pos, runLen)
{
    if (pos != 0)
        translate([
            //-- X: center position along width
            clamp(pos, runLen/2, pcbWidth - runLen/2) - pcbWidth/2,

            //-- Y: inward offset from bottom edge
            (-pcbLength / 2) + (snapInThickness / 2),

            //-- Z: on top of the base plate
            plateThickness
        ])
            rotate([0, 0, 180])
                snapInMount(runLen);
}

module placeLeft(pos, runLen)
{
    if (pos != 0)
        translate([
            //-- X: inward offset from left edge
            (-pcbWidth / 2) + (snapInThickness / 2),

            //-- Y: center position along length
            clamp(pos, runLen/2, pcbLength - runLen/2) - pcbLength/2,

            //-- Z: on top of the base plate
            plateThickness
        ])
            rotate([0, 0, 90])
                snapInMount(runLen);
}

module placeRight(pos, runLen)
{
    if (pos != 0)
        translate([
            //-- X: inward offset from right edge
            (pcbWidth / 2) - (snapInThickness / 2),

            //-- Y: center position along length
            clamp(pos, runLen/2, pcbLength - runLen/2) - pcbLength/2,

            //-- Z: on top of the base plate
            plateThickness
        ])
            rotate([0, 0, -90])
                snapInMount(runLen);
}

//-------------------------------------------------------------
//-- Plate hole generator
//-- Creates circular holes in the base plate if valid positions are defined.
//-- If X and Y coordinates are both 0 → no hole is made.
//-------------------------------------------------------------
module plateHoles(pWidth, pLength, pThickness)
{
    difference()
    {
        //-- Base plate itself
        color("gold")
        translate([ -pWidth/2, -pLength/2, 0 ])
            cube([ pWidth, pLength, pThickness ]);

        //-- Hole 1
        if (!(plateHole1Pos[0] == 0 && plateHole1Pos[1] == 0))
            translate([
                plateHole1Pos[0] - pcbWidth/2,
                plateHole1Pos[1] - pcbLength/2,
                -0.1
            ])
                color("gray") cylinder(h = plateThickness + 0.2, d = plateHole1Pos[2], $fn = 40);

        //-- Hole 2
        if (!(plateHole2Pos[0] == 0 && plateHole2Pos[1] == 0))
            translate([
                plateHole2Pos[0] - pcbWidth/2,
                plateHole2Pos[1] - pcbLength/2,
                -0.1
            ])
                cylinder(h = plateThickness + 0.2, d = plateHole2Pos[2], $fn = 40);

        //-- Hole 3
        if (!(plateHole3Pos[0] == 0 && plateHole3Pos[1] == 0))
            translate([
                plateHole3Pos[0] - pcbWidth/2,
                plateHole3Pos[1] - pcbLength/2,
                -0.1
            ])
                cylinder(h = plateThickness + 0.2, d = plateHole3Pos[2], $fn = 40);

        //-- Hole 4
        if (!(plateHole4Pos[0] == 0 && plateHole4Pos[1] == 0))
            translate([
                plateHole4Pos[0] - pcbWidth/2,
                plateHole4Pos[1] - pcbLength/2,
                -0.1
            ])
                cylinder(h = plateThickness + 0.2, d = plateHole4Pos[2], $fn = 40);
    }
}

//-------------------------------------------------------------
//-- Main Assembly
//-------------------------------------------------------------
module pcbSnapInPlate()
{
    plateWidth  = pcbWidth  + snapInThickness;
    plateLength = pcbLength + snapInThickness;

    //-- Base plate
//    color("gold")
//    translate([ -plateWidth/2, -plateLength/2, 0 ])
//        cube([ plateWidth, plateLength, plateThickness ]);

    //-- Base plate with optional holes
    plateHoles(plateWidth, plateLength, pcbThickness);

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
translate([0,0,-plateThickness + snapInHeight - 0.2])
{
  ;//color([0,0,0,0.5]) cube([pcbWidth, pcbLength, pcbThickness], center=true);  //-- reference PCB
}