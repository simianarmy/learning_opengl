//
//  Shader.vsh
//  TetrahedronSphere
//
//  Created by Marc Mauger on 5/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

attribute vec4 position;

uniform mat4 modelViewProjectionMatrix;

void main()
{
    gl_Position = modelViewProjectionMatrix * position/position.w;
}
