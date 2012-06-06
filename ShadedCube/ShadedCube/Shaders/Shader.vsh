//
//  Shader.vsh
//  ShadedCube
//
//  Created by Marc Mauger on 5/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

attribute vec4 position;
attribute vec4 color;
attribute vec2 texcoord;

varying lowp vec4 colorVarying;
varying lowp vec2 st;

uniform vec3 theta;

void main()
{
    const float  DegreesToRadians = 3.14159265 / 180.0;
    
    vec3 c = cos( DegreesToRadians * theta );
    vec3 s = sin( DegreesToRadians * theta );
    
    mat4 rx = mat4( 1.0, 0.0,  0.0, 0.0,
    0.0, c.x, -s.x, 0.0,
    0.0, s.x,  c.x, 0.0,
    0.0, 0.0,  0.0, 1.0);
    
    mat4 ry = mat4(   c.y, 0.0, s.y, 0.0,
    0.0, 1.0, 0.0, 0.0,
    -s.y, 0.0, c.y, 0.0,
    0.0, 0.0, 0.0, 1.0 );
    
    
    mat4 rz = mat4( c.z, -s.z, 0.0, 0.0,
    s.z,  c.z, 0.0, 0.0,
    0.0,  0.0, 1.0, 0.0,
    0.0,  0.0, 0.0, 1.0 );
    
    gl_Position = rz * ry * rx * position;
    colorVarying = color;
    st    = texcoord;
}
