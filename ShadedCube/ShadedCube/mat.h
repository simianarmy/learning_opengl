//
//  mat.h
//  Perspective Projection
//
//  Created by Marc Mauger on 5/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#ifndef Perspective_Projection_mat_h
#define Perspective_Projection_mat_h

typedef GLKMatrix4 mat4;
typedef GLKVector4 vec4;

inline
mat4 Perspective( const GLfloat fovy, const GLfloat aspect,
                 const GLfloat zNear, const GLfloat zFar)
{
    GLfloat top   = tan(fovy*DegreesToRadians/2) * zNear;
    GLfloat right = top * aspect;
    
    mat4 c = GLKMatrix4Make(
                            zNear/right, 0, 0, 0,
                            0, zNear/top, 0, 0,
                            0, 0, -(zFar + zNear)/(zFar - zNear), -2.0*zFar*zNear/(zFar - zNear),
                            0, 0, -1, 0);

    return c;
}


inline
mat4 Frustum( const GLfloat left, const GLfloat right,
             const GLfloat bottom, const GLfloat top,
             const GLfloat zNear, const GLfloat zFar )
{
    mat4 c = GLKMatrix4Make(2.0*zNear/(right - left), 0, (right + left)/(right - left), 0,
                            0, 2.0*zNear/(top - bottom), (top + bottom)/(top - bottom), 0,
                            0, 0, -(zFar + zNear)/(zFar - zNear), -2.0*zFar*zNear/(zFar - zNear),
                            0, 0, -1.0, 0);
    return c;
}


//----------------------------------------------------------------------------
//
//  Viewing transformation matrix generation
//

inline
mat4 LookAt( const vec4& eye, const vec4& at, const vec4& up )
{
    vec4 n = GLKVector4Normalize(GLKVector4Subtract(eye, at));
    vec4 u = GLKVector4Normalize(GLKVector4CrossProduct(up, n));
    vec4 v = GLKVector4Normalize(GLKVector4CrossProduct(n, u));
    vec4 t = GLKVector4Make(0.0, 0.0, 0.0, 1.0);
    mat4 c = GLKMatrix4MakeWithRows(u, v, n, t);

    return GLKMatrix4Multiply(c, GLKMatrix4MakeTranslation(-eye.x, -eye.y, -eye.z));
}


#endif
