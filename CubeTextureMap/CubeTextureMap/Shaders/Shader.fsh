//
//  Shader.fsh
//  CubeTextureMap
//
//  Created by Marc Mauger on 6/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
