#ifndef MODS_PARTICLES_H
#define MODS_PARTICLES_H

/* Partículas simples para efectos visuales (burbujas de soda al cargar ki).
   Compartido entre mods_game.c (lógica) y gs_draw.c (dibujo). */

#define MODS_PARTICLES_MAX 24

typedef struct {
    float x, y, z;      /* posición en el mundo (o pantalla si es 2D) */
    float vx, vy, vz;   /* velocidad */
    float size;         /* tamaño en píxeles */
    float life;         /* vida restante (0..1) */
    int active;
} ModsParticle;

extern ModsParticle sModsParticles[MODS_PARTICLES_MAX];

/* Agrega una partícula en la posición dada. */
void ModsParticles_Add(float x, float y, float z, float size);

/* Actualiza todas las partículas (llamar una vez por frame). */
void ModsParticles_Update(void);

/* Dibuja todas las partículas activas (llamar desde el render). */
void ModsParticles_Draw(void);

#endif
