#ifndef MODS_PARTICLES_H
#define MODS_PARTICLES_H

/* Partículas para efectos visuales (burbujas de soda, chispas, polvo al cargar ki).
   Compartido entre mods_game.c (lógica) y gs_draw.c (dibujo). */

#define MODS_PARTICLES_MAX 64

/* Tipos de partícula: cada uno tiene comportamiento y aspecto diferente. */
enum {
    MODS_PARTICLE_BUBBLE = 0,   /* burbuja de soda: sube, se desvanece, azul claro */
    MODS_PARTICLE_SPARK = 1,    /* chispa de energía: rápido, amarilla/blanca, breve */
    MODS_PARTICLE_DUST = 2,     /* polvo: cae lento, gris, se disipa */
    MODS_PARTICLE_FLASH = 3,    /* destello: aparece brillante, se apaga rápido */
};

typedef struct {
    int type;          /* tipo de partícula (MODS_PARTICLE_*) */
    float x, y, z;     /* posición en el mundo */
    float vx, vy, vz;  /* velocidad */
    float size;        /* tamaño en píxeles */
    float life;        /* vida restante (0..1) */
    float r, g, b;     /* color (0..1) */
    int active;
} ModsParticle;

extern ModsParticle sModsParticles[MODS_PARTICLES_MAX];

/* Agrega una partícula de tipo dado en la posición. */
void ModsParticles_Add(int type, float x, float y, float z, float size, float r, float g, float b);

/* Actualiza todas las partículas (llamar una vez por frame). */
void ModsParticles_Update(void);

/* Dibuja todas las partículas activas (llamar desde el render). */
void ModsParticles_Draw(void);

#endif
