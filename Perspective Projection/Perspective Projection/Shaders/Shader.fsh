//
//  Shader.fsh
//  Perspective Projection
//
//  Created by Marc Mauger on 5/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
