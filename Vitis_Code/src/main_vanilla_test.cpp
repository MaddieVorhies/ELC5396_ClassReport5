/*****************************************************************//**
 * @file main_vanilla_test.cpp
 *
 * @brief Basic test of 4 basic i/o cores
 *
 * @author p chu
 * @version v1.0: initial release
 *********************************************************************/

//#define _DEBUG
#include "chu_init.h"
#include "gpio_cores.h"
#include "sseg_core.h"
#include "i2c_core.h"
#include "math.h"

/**
 * blink once per second for 5 times.
 * provide a sanity check for timer (based on SYS_CLK_FREQ)
 * @param led_p pointer to led instance
 */
void timer_check(GpoCore *led_p) {
   int i;

   for (i = 0; i < 5; i++) {
      led_p->write(0xffff);
      sleep_ms(500);
      led_p->write(0x0000);
      sleep_ms(500);
      debug("timer check - (loop #)/now: ", i, now_ms());
   }
}

/**
 * check individual led
 * @param led_p pointer to led instance
 * @param n number of led
 */
void led_check(GpoCore *led_p, int n) {
   int i;

   for (i = 0; i < n; i++) {
      led_p->write(1, i);
      sleep_ms(200);
      led_p->write(0, i);
      sleep_ms(200);
   }
}

/**
 * leds flash according to switch positions.
 * @param led_p pointer to led instance
 * @param sw_p pointer to switch instance
 */
void sw_check(GpoCore *led_p, GpiCore *sw_p) {
   int i, s;

   s = sw_p->read();
   for (i = 0; i < 30; i++) {
      led_p->write(s);
      sleep_ms(50);
      led_p->write(0);
      sleep_ms(50);
   }
}

/**
 * uart transmits test line.
 * @note uart instance is declared as global variable in chu_io_basic.h
 */
void uart_check() {
   static int loop = 0;

   uart.disp("uart test #");
   uart.disp(loop);
   uart.disp("\n\r");
   loop++;
}

void adt7420_check(I2cCore *adt7420_p, SsegCore *sseg_p) {
   const uint8_t DEV_ADDR = 0x4b;
   uint8_t wbytes[2], bytes[2];

   uint16_t tmp;
   float tmpC, tmpF;

   wbytes[0] = 0x0b;
   adt7420_p->write_transaction(DEV_ADDR, wbytes, 1, 1);
   adt7420_p->read_transaction(DEV_ADDR, bytes, 1, 0);

   wbytes[0] = 0x00;
   adt7420_p->write_transaction(DEV_ADDR, wbytes, 1, 1);
   adt7420_p->read_transaction(DEV_ADDR, bytes, 2, 0);

   // conversion
   tmp = (uint16_t) bytes[0];
   tmp = (tmp << 8) + (uint16_t) bytes[1];
   if (tmp & 0x8000) {
      tmp = tmp >> 3;
      tmpC = (float) ((int) tmp - 8192) / 16;
      tmpF = ((1.8)*tmpC) + 32.0;
   } else {
      tmp = tmp >> 3;
      tmpC = (float) tmp / 16;
      tmpF = ((1.8)*tmpC) + 32.0;
   }

   int digit1, digit2, digit3, digit4;

   digit1 = (int)tmpF/10;
   digit2 = (int)(tmpF) % 10;
   digit3 = (int)(tmpF * 10.0) % 10;
   digit4 = (int)(tmpF * 100.0) % 10;

   sseg_p->write_1ptn(sseg_p->h2s(digit1), 3);
   sseg_p->write_1ptn(sseg_p->h2s(digit2), 2);
   sseg_p->write_1ptn(sseg_p->h2s(digit3), 1);
   sseg_p->write_1ptn(sseg_p->h2s(digit4), 0);

   sseg_p->set_dp(0x04);

   sleep_ms(500);
}

// instantiate switch, led
GpoCore led(get_slot_addr(BRIDGE_BASE, S2_LED));
GpiCore sw(get_slot_addr(BRIDGE_BASE, S3_SW));
SsegCore sseg(get_slot_addr(BRIDGE_BASE, S8_SSEG));
I2cCore adt7420(get_slot_addr(BRIDGE_BASE, S10_I2C));

int main() {

   while (1) {
      adt7420_check(&adt7420, &sseg);
      debug("main - switch value / up time : ", sw.read(), now_ms());
   } //while
} //main

