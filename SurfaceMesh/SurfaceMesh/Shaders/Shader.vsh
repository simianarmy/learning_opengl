//
//  Shader.vsh
//  SurfaceMesh
//
//  Created by Marc Mauger on 5/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

attribute vec4 position;

varying lowp vec4 colorVarying;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform vec4 fcolor;


void main()
{    
    gl_Position = projectionMatrix * modelViewMatrix * position/position.w;
    colorVarying = fcolor;
}
