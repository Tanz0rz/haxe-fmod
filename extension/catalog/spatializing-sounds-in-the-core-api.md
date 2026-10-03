# spatializing-sounds-in-the-core-api

## 5.0.2 Loading Sounds as 3D
kind: example
index: 0
heading: 5.0.2 Loading Sounds as 3D

### text
```text
result = system->createSound("../media/drumloop.wav", FMOD_3D, 0, &sound);
if (result != FMOD_OK)
{
    HandleError(result);
}
```

## 5.1 Controlling a Spatializer DSP
kind: example
index: 1
heading: 5.1 Controlling a Spatializer DSP

### text
```text
/*
    This code supposes the availability of a maths library with basic support for 3D and 4D vectors and 4x4 matrices:

    // 3D vector
    class Vec3f
    {
    public:
        float x, y, z;

        // Initialize x, y & z from the corresponding elements of FMOD_VECTOR
        Vec3f(const FMOD_VECTOR &v);
    };

    // 4D vector
    class Vec4f
    {
    public:
        float x, y, z, w;

        Vec4f(const Vec3f &v, float w);

        // Initialize x, y & z from the corresponding elements of FMOD_VECTOR
        Vec4f(const FMOD_VECTOR &v, float w);

        // Copy x, y & z to the corresponding elements of FMOD_VECTOR
        void toFMOD(FMOD_VECTOR &v);
    };

    // 4x4 matrix
    class Matrix44f
    {
    public:
        Vec4f X, Y, Z, W;
    };

    // 3D Vector cross product
    Vec3f crossProduct(const Vec3f &a, const Vec3f &b);

    // 4D Vector addition
    Vec4f operator+(const Vec4f &a, const Vec4f &b);

    // 4D Vector subtraction
    Vec4f operator-(const Vec4f& a, const Vec4f& b);

    // Matrix multiplication m * v
    Vec4f operator*(const Matrix44f &m, const Vec4f &v);

    // 4x4 Matrix inverse
    Matrix44f inverse(const Matrix44f &m);
*/

void calculatePannerAttributes(const FMOD_3D_ATTRIBUTES &listenerAttributes, const FMOD_3D_ATTRIBUTES &emitterAttributes, FMOD_DSP_PARAMETER_3DATTRIBUTES &pannerAttributes)
{
    // pannerAttributes.relative is the emitter position and orientation transformed into the listener's space:

    // First we need the 3D transformation for the listener.
    Vec3f right = crossProduct(listenerAttributes.up, listenerAttributes.forward);

    Matrix44f listenerTransform;
    listenerTransform.X = Vec4f(right, 0.0f);
    listenerTransform.Y = Vec4f(listenerAttributes.up, 0.0f);
    listenerTransform.Z = Vec4f(listenerAttributes.forward, 0.0f);
    listenerTransform.W = Vec4f(listenerAttributes.position, 1.0f);

    // Now we use the inverse of the listener's 3D transformation to transform the emitter attributes into the listener's space:
    Matrix44f invListenerTransform = inverse(listenerTransform);

    Vec4f position = invListenerTransform * Vec4f(emitterAttributes.position, 1.0f);

    // Setting the w component of the 4D vector to zero means the matrix multiplication will only rotate the vector.
    Vec4f forward = invListenerTransform * Vec4f(emitterAttributes.forward, 0.0f);
    Vec4f up = invListenerTransform * Vec4f(emitterAttributes.up, 0.0f);
    Vec4f velocity = invListenerTransform * (Vec4f(emitterAttributes.velocity, 0.0f) - Vec4f(listenerAttributes.velocity, 0.0f));

    // We are now done computing the relative attributes.
    position.toFMOD(pannerAttributes.relative.position);
    forward.toFMOD(pannerAttributes.relative.forward);
    up.toFMOD(pannerAttributes.relative.up);
    velocity.toFMOD(pannerAttributes.relative.velocity);

    // pannerAttributes.absolute is simply the emitter position and orientation:
    pannerAttributes.absolute = emitterAttributes;
}
```

## 5.1 Controlling a Spatializer DSP#2
kind: example
index: 2
heading: 5.1 Controlling a Spatializer DSP

### text
```text
do
{
    UpdateGame();       // here the game is updated and the sources would be moved with channel->set3DAttibutes.

    system->set3DListenerAttributes(0, &listener_pos, &listener_vel, &listener_forward, &listener_up);     // update 'ears'

    system->update();   // needed to update 3d engine, once per frame.

} while (gamerunning);
```

## 5.1.1 Velocity
kind: example
index: 3
heading: 5.1.1 Velocity

### text
```text
velx = (posx-lastposx) * 1000 / timedelta;
velz = (posy-lastposy) * 1000 / timedelta;
velz = (posz-lastposz) * 1000 / timedelta;
```

## 5.1.1 Velocity#2
kind: example
index: 4
heading: 5.1.1 Velocity

### text
```text
vel = 0.1 * 1000 / 16.67 = 6 meters per second.
```

## 5.1.1 Velocity#3
kind: example
index: 5
heading: 5.1.1 Velocity

### text
```text
vel = 0.2 * 1000 / 33.33 = 6 meters per second.
```

