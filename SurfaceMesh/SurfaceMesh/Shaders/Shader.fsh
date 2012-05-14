//
//  Shader.fsh
//  SurfaceMesh
//
//  Created by Marc Mauger on 5/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

varying lowp vec4 colorVarying;
uniform vec4 fcolor;

void main()
{
    gl_FragColor = fcolor;
}
