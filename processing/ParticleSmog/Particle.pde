/*
 * A single particle in the noise swarm. Rises like smog/smoke -- the
 * louder the room, the faster, bigger, and more turbulent the rise.
 */
class Particle {
  PVector pos, vel;
  float size, life, maxLife;
  float hue, sat;
  float noiseSeed;

  Particle(float hue, float volume) {
    this.hue = hue;
    this.sat = map(volume, 0, 1, 35, 100);
    pos = new PVector(random(width), height + random(20));
    float speed = map(volume, 0, 1, 0.4, 3.6);
    vel = new PVector(0, -speed);
    size = map(volume, 0, 1, 3, 14) + random(-1.5, 1.5);
    maxLife = map(volume, 0, 1, 90, 220);
    life = maxLife;
    noiseSeed = random(1000);
  }

  void update() {
    float turbulence = map(sat, 0, 100, 0.001, 0.02);
    float angle = noise(noiseSeed, frameCount * turbulence) * TWO_PI * 2;
    vel.x += cos(angle) * 0.05;
    vel.x = constrain(vel.x, -2, 2);

    pos.add(vel);
    life -= 1;
  }

  void display() {
    float alpha = map(life, 0, maxLife, 0, 90);
    noStroke();
    fill(hue, sat, 95, alpha);
    ellipse(pos.x, pos.y, size, size);
  }

  boolean isDead() {
    return life <= 0 || pos.y < -20;
  }
}
