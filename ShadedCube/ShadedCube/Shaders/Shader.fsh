//
//  Shader.fsh
//  ShadedCube
//
//  Created by Marc Mauger on 5/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

varying lowp vec4 colorVarying;
varying lowp vec2 st;

uniform sampler2D texture;

void main()
{
    gl_FragColor = colorVarying * texture2D( texture, st );
}
