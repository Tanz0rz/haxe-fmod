/* KNOWN-CRASH EVIDENCE. CI never runs this.
 *
 * Reproduces a rare FMOD-internal crash (FMOD 2.03.12 and 2.02.33).
 * FMOD computes a 3D channel's geometry occlusion on its geometry
 * thread. A geometry release while such a request is in flight can
 * leave the thread reading a null pointer. No channel group is released
 * here, so this is a separate defect from the one in
 * fmod_geometry_group_release_repro.c. The rate is low, about one crash
 * in several thousand cycles of this tight pattern.
 *
 * Each cycle creates a geometry, moves 3D channels so the next update
 * queues their occlusion requests, waits 0 to 25 ms, and releases the
 * geometry. Pure C against the FMOD API, so no binding layer is
 * involved.
 *
 *   gcc -g -O1 fmod_last_geometry_release_repro.c -I$FMOD_SDK/api/core/inc \
 *     -I$FMOD_SDK/api/studio/inc -L$FMOD_SDK/api/core/lib/x86_64 \
 *     -L$FMOD_SDK/api/studio/lib/x86_64 -lfmodstudio -lfmod -lpthread
 *   ./a.out <cycles> <channels> <polygons>     for example 4000 16 1
 */
#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "fmod.h"
#include "fmod_studio.h"
static void msleep(double ms){struct timespec ts={(time_t)(ms/1000),(long)((ms-1000*(long)(ms/1000))*1e6)};nanosleep(&ts,NULL);}
int main(int argc,char**argv){
  int cycles=atoi(argv[1]), nch=atoi(argv[2]), npoly=atoi(argv[3]);
  FMOD_STUDIO_SYSTEM* st; FMOD_SYSTEM* core; FMOD_Studio_System_Create(&st, FMOD_VERSION); FMOD_Studio_System_GetCoreSystem(st,&core);
  FMOD_System_SetOutput(core, FMOD_OUTPUTTYPE_NOSOUND);
  if (FMOD_Studio_System_Initialize(st, 512, FMOD_STUDIO_INIT_NORMAL, FMOD_INIT_NORMAL, NULL)!=FMOD_OK) return 2;
  FMOD_3D_ATTRIBUTES l; memset(&l,0,sizeof l); l.position.x=-5; l.forward.z=1; l.up.y=1;
  FMOD_Studio_System_SetListenerAttributes(st,0,&l,NULL);
  FMOD_CREATESOUNDEXINFO ex; memset(&ex,0,sizeof ex); ex.cbsize=sizeof ex; ex.numchannels=1; ex.defaultfrequency=48000; ex.format=FMOD_SOUND_FORMAT_PCM16; ex.length=48000*2;
  FMOD_SOUND* snd; FMOD_System_CreateSound(core,NULL,FMOD_OPENUSER|FMOD_3D|FMOD_LOOP_NORMAL,&ex,&snd);
  FMOD_CHANNEL** chs=calloc(nch,sizeof*chs); FMOD_VECTOR z={0,0,0};
  for(int i=0;i<nch;i++){ FMOD_System_PlaySound(core,snd,NULL,0,&chs[i]); FMOD_VECTOR p={5,(float)(i%20)-10,0}; FMOD_Channel_Set3DAttributes(chs[i],&p,&z);}
  srand(time(NULL));
  for(int c=0;c<cycles;c++){
    FMOD_GEOMETRY* geo; FMOD_System_CreateGeometry(core, npoly, npoly*4, &geo);
    for(int i=0;i<npoly;i++){ float x=-4.5f+9.0f*i/npoly; FMOD_VECTOR q[4]={{x,-10,-10},{x,10,-10},{x,10,10},{x,-10,10}}; int pi; FMOD_Geometry_AddPolygon(geo,0.3f,0.3f,1,4,q,&pi);}
    FMOD_CHANNELGROUP* g = NULL;
    FMOD_VECTOR at={5,0,0}, mv={5.02f,0,0}; 
    FMOD_CHANNEL* gc; FMOD_System_PlaySound(core,snd,g,0,&gc); FMOD_Channel_Set3DAttributes(gc,&at,&z);
    msleep(20);
    FMOD_Channel_Set3DAttributes(gc,&mv,&z);
    for(int i=0;i<nch;i++){ FMOD_VECTOR p={5+0.01f*(c%2),(float)(i%20)-10,0}; FMOD_Channel_Set3DAttributes(chs[i],&p,&z);}
    msleep((rand()%2500)/100.0);
    FMOD_Channel_Stop(gc);
    FMOD_Geometry_Release(geo);
    msleep(60);
    if(c%100==0){printf("cycle %d\n",c);fflush(stdout);}
  }
  printf("survived %d\n",cycles); return 0;
}
