//
//  Shader.vsh
//  Perspective Projection
//
//  Created by Marc Mauger on 5/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

attribute vec4 position;
attribute vec4 color;

varying lowp vec4 colorVarying;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

void main()
{    
    gl_Position = projectionMatrix * modelViewMatrix * position/position.w;
    colorVarying = color;
}
