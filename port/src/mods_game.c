/*
 * Script mods, the game's side (the scripts themselves: port/src/gs/mods.c; docs/port/mods.md). Once per blank on the
 * game's thread this file reads what the scripts are given of a fight beyond the gauges (fight_panels.c reads those):
 * where each fighter is. And it is where the camera hook in src/battle/btl_cam.c (BtlCam_UpdateView) comes in: the
 * pose the game gives the battle view each frame is handed to the scripts' on_camera and the pose they return is
 * the one built and drawn. It also holds the fighters' face gesture (bt3.look `face`, from BtlObj_UpdateAll): the
 * game's own mouth-open face and serious eyes while charging ki.
 *
 * That pose is only drawn: nothing of the fight reads it back (include/battle/btl_char_cam.h: only
 * BtlCharApi_GetCamPose reads ChrCam.pos / rot; stick movement goes by ChrCam.yaw), and the game builds the view
 * from the fighter camera again at the start of the next frame. The other readers of the view are drawing, effects
 * and sound (include/battle/btl_cam.h). Blanks run again after a rollback, and self-check runs (BT3_SYNCTEST), get
 * the game's pose as it is. Cuts (techniques, transformations), fixed and frozen cameras are not handed over.
 *
 * Nothing here draws a game random number or writes anything but that view. This file's variables are not game
 * state (port/tools/make_state.py).
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "gs/mods.h"
#include "port_addr.h"

#if (defined(__x86_64__) || defined(__aarch64__)) && defined(__clang__)
#undef __ptr32 /* the Windows headers of mingw define these two away */
#undef __uptr
#define GAME_PTR *__ptr32 __uptr
#else
#define GAME_PTR *
#endif

extern int gPortResim; /* gs/state.c: blanks being run again */
extern int gsSkipFrame; /* gs_draw.c: a presentation frame deliberately discarded */
extern void GAME_PTR gBtlChars;
extern void GAME_PTR gBtlSeq;
extern void GAME_PTR BtlChar_FindByObjId(int objId);
extern void GAME_PTR BtlChar_FindBySide(int side);
extern int BtlChar_TestFlag(void GAME_PTR chr, unsigned n);
extern int ChrCam_IsCutActive(void GAME_PTR chr);
extern int Battle_IsSplitScreen(void);
extern int TagBattle_Active(void),TagBattle_Count(void),TagBattle_ViewActor(void),TagBattle_Target(int actor);
extern int BattleSide_GetObjId(int side);
extern int PortSpectator_Mode(void);
/* gs/ui.h declares this, but it also pulls in SDL3's headers, which only the files under gs/ are built with; and
   the values come back through pointers, not as a float return, because this file is built without the FPU. */
extern void PortInput_MouseRead(float *dx, float *dy, int *left);

int PortMods_ViewActor(int side) {
    int own,target,count;
    if(!TagBattle_Active())return side;
    count=TagBattle_Count();own=TagBattle_ViewActor();
    if(own<0 || own>=count)own=0;
    target=TagBattle_Target(own);
    return side==0?own:target>=0&&target<count?target:own;
}

#define CHR_POSE 0x10        /* include/battle/btl_act_a.h: the pose block; pos at +0x00 */
#define POSE_YAW 0x94        /* ... heading yaw */
#define CHR_CAM_TARGET 0x450 /* include/battle/btl_char_cam.h: ChrCam target */

static ModsGame sGame;
static ModsCam sCam;
static int sCamOut;
/* Presentation-only, one last requested pose per view, not a frame history. */
static struct { int valid,obj; ModsCam pose; } sPausedCamera[2];
struct NaturalPose { int valid,obj; float pos[3],rot[3],anchor[3]; };
static struct NaturalPose sNatural[10];
int PortMods_InBattle(void) { return sGame.battle; }

/* Hair, tail and cape physics for src/battle/bobj_b_b.c (BtlObj_UpdateChains): the script mods' bt3.look
   `jiggle` as a percentage of the movement the game's own chains take (100 = the game's own, up to 300 at
   the slider's top). The chains themselves keep their limits, so the motion cannot stretch the model. Online,
   the chain angles are part of the synchronised state: the game's own value is kept there. */
int Port_ModsChainGain(void) {
    extern int Port_NetActive(void);
    const ModsLook *look;
    int jiggle;

    if (Port_NetActive()) {
        return 100;
    }
    look = Mods_Look();
    jiggle = look != NULL ? look->jiggle : 0;
    if (jiggle < 0) jiggle = 0;
    if (jiggle > 100) jiggle = 100;
    return 100 + jiggle * 2;
}

/* Mouth and eyes of a fighter, for src/battle/btl_obj.c (BtlObj_UpdateAll): the script mods' bt3.look `face` shows
   the states the game's own animation events use while the fighter charges ki (action 0x37): the mouth held open
   (BOBJ_MOUTH_HOLD_OPEN: shape 6, the jaw turned by its 21 degrees) and eye frame 2, the expression those events ask
   for. Each model keeps what it was built with: an eye table with fewer frames, or a mouth without that set, is left
   as the game draws it. Only the picture: the fight reads neither state back (bobj_b.h marks both "(v)"), and when the
   charge ends the state is handed back to the game only if it is still the one this put there. */
#define BOBJ_EYES 0x4C /* include/battle/bobj_b.h: BObjMdl.eyes at object + 0x4C (a 4-byte game pointer, NULL: no eyes) */
#define BTL_OBJ_COUNT 12 /* include/battle/btl_obj.h: BTL_OBJ_MAX */
#define FACE_CHARGE_ACTION 0x37 /* the ki charge (mods.c `charging`) */
#define FACE_CHARGE_MOUTH 10    /* BOBJ_MOUTH_HOLD_OPEN */
#define FACE_CHARGE_EYE 2       /* the frame the game's animation event 0x800000000000000 forces */
static unsigned char sFaceOwn[BTL_OBJ_COUNT]; /* the mouth / eyes of this object are the ones this put there */

void Port_ModsFaceGestures(int objId) {
    extern void GAME_PTR BtlObj_Get(int objId);
    extern void GAME_PTR BtlChar_FindByObjId(int objId);
    extern int BtlAct_GetCurrent(void GAME_PTR chr);
    extern void BtlObj_SetSubState(void GAME_PTR obj, int mode, int arg);
    extern void BtlObj_SetEyeFrame(void GAME_PTR obj, unsigned frame);
    extern int BtlObj_GetMouthMode(void GAME_PTR obj);
    extern int BtlObj_GetEyeFrame(void GAME_PTR obj);
    const ModsLook *look = Mods_Look();
    uint8_t GAME_PTR obj, chr;
    uint32_t eyes;

    if (gPortResim || objId < 0 || objId >= BTL_OBJ_COUNT) {
        return;
    }
    obj = (uint8_t GAME_PTR)BtlObj_Get(objId);
    if (obj == NULL) {
        return;
    }
    chr = (uint8_t GAME_PTR)BtlChar_FindByObjId(objId);
    if (chr != NULL && look != NULL && look->face > 0 && BtlAct_GetCurrent(chr) == FACE_CHARGE_ACTION) {
        if (BtlObj_GetMouthMode(obj) != FACE_CHARGE_MOUTH) { /* (this frame's own events may have changed it) */
            BtlObj_SetSubState(obj, FACE_CHARGE_MOUTH, 0);
        }
        eyes = *(uint32_t GAME_PTR)(obj + BOBJ_EYES); /* (the eye table's game address, 0: no eyes) */
        if (eyes != 0 && *(const uint32_t *)Port_Ptr(eyes) >= FACE_CHARGE_EYE) { /* (its first word: how many) */
            BtlObj_SetEyeFrame(obj, FACE_CHARGE_EYE);
        }
        sFaceOwn[objId] = 1;
        return;
    }
    if (!sFaceOwn[objId]) {
        return;
    }
    if (BtlObj_GetMouthMode(obj) == FACE_CHARGE_MOUTH) {
        BtlObj_SetSubState(obj, 0, 0);
    }
    if (BtlObj_GetEyeFrame(obj) == FACE_CHARGE_EYE) {
        BtlObj_SetEyeFrame(obj, 9); /* (9: the eyes go back to blinking) */
    }
    sFaceOwn[objId] = 0;
}

/* Host presentation preference, never included in gameplay snapshots. */
int Port_SpecialMoveCameras(int change) {
    extern int Port_Setting(const char *,int);
    extern void Port_SettingSave(const char *,int),Port_SettingsWrite(void);
    static int enabled=-1;
    if(enabled<0)enabled=Port_Setting("special_move_cameras",1)!=0;
    if(change>=0){enabled=change!=0;Port_SettingSave("special_move_cameras",enabled);Port_SettingsWrite();}
    return enabled;
}

static void rdf(float *out, uint8_t GAME_PTR p, int off, int n) {
    int i;
    uint32_t v;

    for (i = 0; i < n; i++) { /* (the bits as they are: no float operation in this software-float file) */
        v = *(uint32_t GAME_PTR)(p + off + i * 4);
        memcpy(&out[i], &v, 4);
    }
}

/* n floats at a game address (Port_Ptr) <-> here, as bits */
static void rda(float *out, uint32_t addr, int n) {
    memcpy(out, Port_Ptr(addr), (size_t)n * 4);
}
static void wra(uint32_t addr, const float *in, int n) {
    memcpy(Port_Ptr(addr), in, (size_t)n * 4);
}

/* Keep a regular chase framing during special-move cuts. The cached pose and
   its anchor are presentation data; no fighter camera or input is changed. */
void Port_NaturalFightCamera(int objId,int pos,int rot) {
    extern int BtlAct_GetCurrent(void GAME_PTR);
    uint8_t GAME_PTR chr=(uint8_t GAME_PTR)BtlChar_FindByObjId(objId);
    float anchor[3],p[3],r[3];int action,cut,i,slot=objId>=0?objId%10:0;
    struct NaturalPose *s=&sNatural[slot];
    if(gPortResim)return;
    if(!chr)return;
    action=BtlAct_GetCurrent(chr);
    cut=ChrCam_IsCutActive(chr)||(action>=0xFD && action<=0x13B);
    rdf(anchor,chr,CHR_POSE,3);rda(p,(uint32_t)pos,3);rda(r,(uint32_t)rot,3);
    if(!cut){s->valid=1;s->obj=objId;memcpy(s->pos,p,sizeof(p));memcpy(s->rot,r,sizeof(r));memcpy(s->anchor,anchor,sizeof(anchor));}
    else if(!Port_SpecialMoveCameras(-1)&&s->valid&&s->obj==objId){
        for(i=0;i<3;++i)p[i]=s->pos[i]+anchor[i]-s->anchor[i];
        wra((uint32_t)pos,p,3);wra((uint32_t)rot,s->rot,3);
    }
}

void PortMods_GameTick(void) {
    int side;
    uint8_t GAME_PTR chr;

    if (gPortResim) {
        return;
    }
    memset(&sGame, 0, sizeof(sGame));
    if (gBtlChars != NULL && gBtlSeq != NULL) {
        for (side = 0; side < 2; side++) {
            chr = (uint8_t GAME_PTR)BtlChar_FindBySide(PortMods_ViewActor(side));
            if (chr != NULL) {
                sGame.f[side].found = 1;
                rdf(sGame.f[side].pos, chr, CHR_POSE, 3);
                rdf(&sGame.f[side].yaw, chr, CHR_POSE + POSE_YAW, 1);
            }
        }
        sGame.battle = sGame.f[0].found && sGame.f[1].found;
        sGame.split = sGame.battle && Battle_IsSplitScreen();
    } else { memset(sNatural,0,sizeof(sNatural)); memset(sPausedCamera,0,sizeof(sPausedCamera)); }
    PortInput_MouseRead(&sGame.mouseDx,&sGame.mouseDy,&sGame.mouseLeft);
    Mods_Tick();
}

int PortMods_Read(ModsGame *out) {
    memcpy(out, &sGame, sizeof(*out));
    return sGame.battle;
}

int PortMods_CamGet(ModsCam *out) {
    memcpy(out, &sCam, sizeof(*out));
    return 1;
}

void PortMods_CamSet(const ModsCam *cam) {
    memcpy(sCam.pos, cam->pos, sizeof(sCam.pos));
    memcpy(sCam.rot, cam->rot, sizeof(sCam.rot));
    sCam.zoom=cam->zoom;
    sCam.collide=cam->collide;
    sCamOut = 1;
}

/* From BtlCam_UpdateView (src/battle/btl_cam.c): `pos` and `rot` are the addresses of the view's pose in game
   memory, just copied from the side's fighter camera. */
/* What the scripts asked of this side's camera besides its pose, for src/battle/btl_cam.c: the zoom (thousandths,
   1000 the game's) and whether the pose is to be kept out of the stage. The game's values when no mod changed it. */
static int sZoom[2] = {1000, 1000}, sCollide[2];
int Port_ModsCamZoom(int side) {
    return side >= 0 && side < 2 ? sZoom[side] : 1000;
}
int Port_ModsCamCollide(int side) {
    return side >= 0 && side < 2 ? sCollide[side] : 0;
}

void Port_ModsCamera(int side, int objId, int pos, int rot, int paused) {
    static int synctest = -1;
    uint8_t GAME_PTR chr;

    if (synctest < 0) {
        synctest = getenv("BT3_SYNCTEST") != NULL;
    }
    /* A render skip is chosen on the renderer thread. It must not decide
       whether the simulation builds a native or modified view: the choice
       can change before this tick's list is consumed. Only rollback skips
       presentation state. Renderer frame dropping remains independent. */
    if (gPortResim || side < 0 || side > 1) return;
    sZoom[side]=1000;sCollide[side]=0;
    if (synctest || PortSpectator_Mode() || !Mods_WantCamera()) {
        sPausedCamera[side].valid=0;
        return;
    }
    chr = (uint8_t GAME_PTR)BtlChar_FindByObjId(objId);
    if (chr == NULL) {
        return;
    }
    memset(&sCam, 0, sizeof(sCam));
    sCam.side = side;
    /* the game's own camera work: cuts, fixed and frozen cameras (fighter flags 0xCC, 0xCD, 0xDC, 0xB8) */
    sCam.cut = ChrCam_IsCutActive(chr) || BtlChar_TestFlag(chr, 0xCC) || BtlChar_TestFlag(chr, 0xDC) ||
               BtlChar_TestFlag(chr, 0xB8) || BtlChar_TestFlag(chr, 0xCD);
    rda(sCam.pos, (uint32_t)pos, 3);
    rda(sCam.rot, (uint32_t)rot, 3);
    rdf(sCam.target, chr, CHR_CAM_TARGET, 3);
    sCam.zoom = 1.0f;
    sCam.collide = 1;
    sCamOut = 0;
    if (paused && !sCam.cut && sPausedCamera[side].valid && sPausedCamera[side].obj==objId) {
        sCam=sPausedCamera[side].pose;
        sCamOut=1;
    } else {
        Mods_Camera();
        sPausedCamera[side].valid=sCamOut && !sCam.cut;
        sPausedCamera[side].obj=objId;
        sPausedCamera[side].pose=sCam;
    }
    if (sCamOut) {
        wra((uint32_t)pos, sCam.pos, 3);
        wra((uint32_t)rot, sCam.rot, 3);
        sZoom[side] = (int)(sCam.zoom * 1000.0f + 0.5f);
        sCollide[side] = sCam.collide;
    }
}
