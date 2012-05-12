//
//  Shader.vsh
//  Sierpinski3D
//
//  Created by Marc Mauger on 4/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

attribute vec4 position;

varying lowp vec4 colorVarying;

void main()
{
    colorVarying = vec4((1.0 + position.xyz)/2.0, 1.0);
    gl_Position = position;
}
