#include <Wire.h>
#include <LiquidCrystal.h>
//#include <Ard2990.h>

LiquidCrystal lcd(8, 13, 9, 4, 5, 6, 7);

int adc_key_val[5] ={50, 200, 400, 600, 800 };
int NUM_KEYS = 5;
int adc_key_in;
int key=-1;
int oldkey=-1;

void setup()
{
  lcd.clear(); 
  lcd.begin(16, 2);
  lcd.setCursor(0,0); 
  lcd.print("LTC2990 Tester"); 
  Wire.begin();
}

void loop()
{
  int addr;
  uint16_t t;
  float temperature;
  
  lcd.setCursor(0,1);
  lcd.print("Select to Start");

  waitForSelect();

  lcd.clear();
  lcd.print("Enumerating...");
  
  addr = enumerateI2C();
  delay(1000);
  
  // Configure
  lcd.clear();
  lcd.print("Configure...");
  Wire.beginTransmission(addr);
  Wire.write(0x01);
  Wire.write(0xDD);  // 1101 1101
  Wire.endTransmission();
  delay(500);

  // Read Temperature
  lcd.clear();
  while(1)
  {
    // Trigger
    lcd.setCursor(0,0);
    lcd.print("Trigger...     ");
    Wire.beginTransmission(addr);
    Wire.write(0x02);
    Wire.write(0x00);
    Wire.endTransmission();
    delay(500);

    lcd.setCursor(0,0);
    lcd.print("Temperatures...");

    Wire.beginTransmission(addr);
    Wire.write(0x06);
    Wire.endTransmission(false);
    if(Wire.requestFrom(addr, 1, true) == 1)
    {
      t = (Wire.read() & 0x1F) << 8;
    }

    Wire.beginTransmission(addr);
    Wire.write(0x07);
    Wire.endTransmission(false);
    if(Wire.requestFrom(addr, 1, true) == 1)
    {
      t += Wire.read();
    }
    
    temperature = (((t / 16.0) - 273.15) * 1.8) + 32;
    lcd.setCursor(0,1);
    lcd.print(temperature, 1);

    lcd.print("  ");
    
    Wire.beginTransmission(addr);
    Wire.write(0x0A);
    Wire.endTransmission(false);
    if(Wire.requestFrom(addr, 1, true) == 1)
    {
      t = (Wire.read() & 0x1F) << 8;
    }

    Wire.beginTransmission(addr);
    Wire.write(0x0B);
    Wire.endTransmission(false);
    if(Wire.requestFrom(addr, 1, true) == 1)
    {
      t += Wire.read();
    }
    
    temperature = (((t / 16.0) - 273.15) * 1.8) + 32;
    lcd.print(temperature, 1);
    
    delay(1000);
  }
}

// Convert ADC value to key number
int get_key(unsigned int input)
{
    int k;
   
    for (k = 0; k < NUM_KEYS; k++)
    {
      if (input < adc_key_val[k])
 {
            return k;
        }
   }
   
    if (k >= NUM_KEYS)k = -1;  // No valid key pressed
    return k;
}


uint8_t enumerateI2C(void)
{
  uint8_t addr, stat, last_ack = 0x00, i=0;
  for(addr=0; addr<128; addr++)
  {
    Wire.beginTransmission(addr);
    stat = Wire.endTransmission();
    if(!stat)
    {
      lcd.setCursor(i*5,1);
      lcd.print("0x");
      lcd.print(addr, HEX);
      if(0x77 != addr)  // Return non-global address
        last_ack = addr;
      i++;
    }
  }
  return last_ack;
}

void waitForSelect(void)
{
  while (key == oldkey)
  {
    adc_key_in = analogRead(0);    // read the value from the sensor 
    key = get_key(adc_key_in);  // convert into key press
  
    if (key != oldkey)   // if keypress is detected
    {
      delay(50);  // wait for debounce time
      adc_key_in = analogRead(0);    // read the value from the sensor 
      key = get_key(adc_key_in);    // convert into key press
    }
    if(4 != key)
    {
      oldkey = key;
    }
  }
  oldkey = key;
}

