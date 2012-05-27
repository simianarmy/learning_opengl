//
//  Shader.vsh
//  ShadedCube
//
//  Created by Marc Mauger on 5/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

attribute vec4 position;
attribute vec4 color;

varying lowp vec4 colorVarying;

void main()
{
    gl_Position = position;
    colorVarying = color;
}
