/*
 * Noise Pollution -- live particle render driven by Pure Data audio analysis.
 * Receives plain UDP text from pd/noise_pollution.pd on port 12000, e.g.:
 *   "volume 0.42"
 *   "pitch 220.5"
 * Volume drives particle count/speed/size/saturation, pitch drives hue.
 * No external Processing library needed -- just java.net.DatagramSocket.
 *
 * The canvas always reflects the CURRENT acoustic state of the room:
 * quiet = a few slow, pale, drifting particles; loud/harsh = a dense,
 * fast, saturated swarm. Nothing accumulates -- it fades out within
 * seconds of the sound stopping.
 */

import java.net.DatagramPacket;
import java.net.DatagramSocket;

final int UDP_PORT = 12000;
final float MIN_FREQ = 60;    // low rumble (traffic, HVAC)
final float MAX_FREQ = 4000;  // sharp/harsh (sirens, screeches)
final float HUE_RANGE = 300;  // red -> violet, leaves out the red/violet seam

// WHO guidance treats sustained exposure above ~85 dB(A) as harmful.
// We don't have calibrated dB here, just a normalized 0-1 envelope,
// so this is a stylistic "high alert" threshold on that normalized scale.
final float ALERT_VOLUME = 0.8;

DatagramSocket udpSocket;
volatile float rawPitch = 220;
volatile float rawVolume = 0;
volatile long lastMsgTime;

float pitch = 220;      // smoothed
float volume = 0;       // smoothed

ArrayList<Particle> particles = new ArrayList<Particle>();
boolean showHUD = true;

void settings() {
  size(1000, 700);
}

void setup() {
  colorMode(HSB, 360, 100, 100, 100);
  background(0, 0, 6);
  lastMsgTime = millis();
  try {
    udpSocket = new DatagramSocket(UDP_PORT);
    Thread listener = new Thread(this::listenUDP);
    listener.setDaemon(true);
    listener.start();
  } catch (Exception e) {
    println("Could not open UDP port " + UDP_PORT + ": " + e.getMessage());
  }
}

void listenUDP() {
  byte[] buf = new byte[512];
  while (true) {
    try {
      DatagramPacket packet = new DatagramPacket(buf, buf.length);
      udpSocket.receive(packet);
      String msg = new String(packet.getData(), 0, packet.getLength());
      parseMessage(msg);
    } catch (Exception e) {
      // socket closed on sketch exit, or a malformed packet -- just keep going
    }
  }
}

void parseMessage(String msg) {
  // Pd's netsend (text mode) terminates each message with " ;" -- strip it.
  String[] parts = msg.replace(";", " ").trim().split("\\s+");
  if (parts.length < 2) return;
  try {
    float val = Float.parseFloat(parts[1]);
    if (parts[0].equals("volume")) {
      rawVolume = constrain(val, 0, 1);
      lastMsgTime = millis();
    } else if (parts[0].equals("pitch")) {
      rawPitch = val;
      lastMsgTime = millis();
    }
  } catch (NumberFormatException e) {
    // ignore malformed atom
  }
}

void draw() {
  // silence fallback: if Pd isn't sending anything at all, decay to calm
  if (millis() - lastMsgTime > 1000) {
    rawVolume = 0;
  }

  pitch = lerp(pitch, rawPitch, 0.12);
  volume = lerp(volume, rawVolume, 0.15);

  // short live trail, not an accumulating painting -- always shows "now"
  noStroke();
  fill(0, 0, 6, 55);
  rect(0, 0, width, height);

  spawnParticles();
  updateAndDrawParticles();

  if (showHUD) drawHUD();
}

void spawnParticles() {
  float hue = freqToHue(pitch);
  int count = int(map(volume, 0, 1, 0, 35));
  for (int i = 0; i < count; i++) {
    particles.add(new Particle(hue, volume));
  }
}

void updateAndDrawParticles() {
  for (int i = particles.size() - 1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update();
    p.display();
    if (p.isDead()) particles.remove(i);
  }
}

float freqToHue(float freq) {
  freq = constrain(freq, MIN_FREQ, MAX_FREQ);
  float t = (log(freq) - log(MIN_FREQ)) / (log(MAX_FREQ) - log(MIN_FREQ));
  return t * HUE_RANGE;
}

void drawHUD() {
  noStroke();
  fill(0, 0, 100, 85);
  textSize(13);
  text("pitch: " + int(pitch) + " Hz", 16, 24);
  text("volume: " + nf(volume, 1, 2), 16, 42);
  text("particles: " + particles.size(), 16, 60);
  text(volume > ALERT_VOLUME ? "-- high noise level --" : "", 16, 78);
  text("[h] hide HUD", 16, height - 16);
}

void keyPressed() {
  if (key == 'h' || key == 'H') showHUD = !showHUD;
}

void stop() {
  if (udpSocket != null) udpSocket.close();
}
