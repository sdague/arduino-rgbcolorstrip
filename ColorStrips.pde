#include <Bounce.h>

/*
  ColorStrips - this is code that works with a set of RGB color strips
  to produce a rotating color wheel, as well as simulated sunrise.

  Based originally on the Fading tutorial.

  Copyright 2011 - Sean Dague <sean@dague.net>
  Released under MIT License

*/

#define ROTARY1 2
#define ROTARY2 7
#define RPIN 9
#define GPIN 10
#define BPIN 11
#define LED 13

#define DIALCOLOR 2
#define SUNRISE 0
#define COLORWHEEL 1

#define POT1 0
#define BUTTON 4
#define WHEELMAX 256 * 6

int wheelDelay = 30;
int sunDelay = 60;
int wheelPos = 0;

int encoderValue = 0;
int encoderSpeed = 1;

Bounce bouncer = Bounce( BUTTON, 30);
Bounce rotary = Bounce( ROTARY1, 5);

unsigned long lastChanged = 0;
// analog in value
int val = 0;

// increment to use during the sun calculations
int sunInc = 1;

int state = LOW;

int color[3] = {
    0, 0, 0};

int R = 0;
int G = 1;
int B = 2;

void setup()  { 
    // nothing happens in setup 
    Serial.begin(9600);
    // attachInterrupt(0, encoderRead, CHANGE);
    pinMode(RPIN, OUTPUT);
    pinMode(GPIN, OUTPUT);
    pinMode(BPIN, OUTPUT);
    pinMode(BUTTON, INPUT);
    pinMode(ROTARY1, INPUT);
    pinMode(ROTARY2, INPUT);
}

void resetColor() {
    wheelPos = 0;
}

void setColorRaw() {
    analogWrite(RPIN, color[R]);
    analogWrite(GPIN, color[G]);
    analogWrite(BPIN, color[B]);
}

void setColor() {
    float gbias = 1.0;

    float green = (float)color[G] * gbias;
    float red = (float)color[R];
    float blue = (float)color[B];

    // normalize to intensity
    float intensity = sqrt(255.0 / (green + red + blue));

    analogWrite(RPIN, (int)(red * intensity));
    analogWrite(GPIN, (int)(green * intensity));
    analogWrite(BPIN, (int)(blue * intensity));
}

int timeToFade(long d) {
    unsigned long currentMillis = millis();
    if (currentMillis > (lastChanged + d)) {
        lastChanged = currentMillis;
        return 1;
    }
    // handle overflow
    if (lastChanged > currentMillis) {
        lastChanged = currentMillis;
    }
    return 0;
}

void wheelToSunRise(int wheel) {
    //    int red = (int) (sqrt((float) wheel) * 8.0);
    int red = wheel / 4;
    if (red > 255) {
        red = 255;
    }

    int green = (red / 4) + (wheel - 256) / 10;
    if (green < 0) {
        green = 0;
    } else if (green > 255) {
        green = 255;
    }

    color[R] = red;
    color[G] = green;
    color[B] = 0;
}

void wheelToRGB(int wheel) {
    int hue = wheel;
    int range = hue / 255;
    hue = hue % 255;

    if (range == 0) {
        color[R] = 255;
        color[G] = hue;
        color[B] = 0;
    } 
    else if (range == 1) {
        color[R] = 255 - hue;
        color[G] = 255;
        color[B] = 0;
    } 
    else if (range == 2) {
        color[R] = 0;
        color[G] = 255;
        color[B] = hue;
    } 
    else if (range == 3) {
        color[R] = 0;
        color[G] = 255 - hue;
        color[B] = 255;
    } 
    else if (range == 4) {
        color[R] = hue;
        color[G] = 0;
        color[B] = 255;
    } 
    else if (range == 5) {
        color[R] = 255;
        color[G] = 0;
        color[B] = 255 - hue;
    } 
    else {
        color[R] = 255;
        color[G] = 0;
        color[B] = 0;
    }
}

void computeHue(int val) {
    int hue = (int)((float)val * 1.5);
    wheelToRGB(hue);
}

void colorWheel() {
    int inc = 2;
    if(timeToFade(wheelDelay)) {

        wheelToRGB(wheelPos);
        setColor();
    
        wheelPos += inc;
        if(wheelPos > WHEELMAX) {
            wheelPos = 0; 
        }
    }
}

void sunRise() {
    if(timeToFade(sunDelay)) {
        wheelToSunRise(wheelPos);
        setColorRaw();

        wheelPos += sunInc;
        if(wheelPos >= WHEELMAX) {
            wheelPos = WHEELMAX - 1;
            sunInc = 0 - sunInc;
        } else if (wheelPos < 0) {
            wheelPos = 0;
            sunInc = 0 - sunInc;
        }
    }
}

void resetState(int state) {
    if (state == DIALCOLOR) {
        encoderValue = wheelPos;
    } else if (state == SUNRISE) {
        wheelPos = 0;
    } else if (state == COLORWHEEL) {
        wheelPos = encoderValue;
    }
}

void checkMode() {
    bouncer.update();

    if ( bouncer.risingEdge()) {
        state++;
        if (state > 3) {
            state = 0;
        }
        resetState(state);
    }

    rotary.update();
    if (rotary.risingEdge()) {
        encoderRead();
    }
}

void encoderRead() {
    if (state == DIALCOLOR) {
        if (digitalRead(ROTARY1) == digitalRead(ROTARY2)) {
            encoderValue -= 3;
        } else {
            encoderValue += 3;
        }
        
        if (encoderValue < 0) {
            encoderValue += WHEELMAX;
        } else if (encoderValue >= WHEELMAX) {
            encoderValue -= WHEELMAX;
        }
    } else if (state == SUNRISE) {
        if (digitalRead(ROTARY1) == digitalRead(ROTARY2)) {
            if (sunDelay < 200) {
                sunDelay += 10;
            }
        } else {
            if (sunDelay > 10) {
                sunDelay -= 10;
            }
        }
    } else if (state == COLORWHEEL) {
        if (digitalRead(ROTARY1) == digitalRead(ROTARY2)) {
            if (wheelDelay < 60) {
                wheelDelay += 5;
            }
        } else {
            if (wheelDelay > 5) {
                wheelDelay -= 5;
            }
        }
    }
}

void dialColor() {
    wheelPos = encoderValue;
    wheelToRGB(wheelPos);
    setColor();
}

void loop() {
    checkMode();
    if (state == SUNRISE) {
        sunRise();
    } else if (state == COLORWHEEL) {
        colorWheel();
    }  else {
        dialColor();
    }
}




