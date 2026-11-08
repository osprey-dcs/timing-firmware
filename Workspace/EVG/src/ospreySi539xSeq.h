/*
 * ospreySi539xSeq.h -- register map and command encoders for the
 * ospreySi539xSeq SPI sequencer (one instance per Si539x chip).
 * Offsets are bytes from the instance's AXI base address.
 */
#ifndef OSPREY_SI539X_SEQ_H
#define OSPREY_SI539X_SEQ_H

#include <stdbool.h>
#include <stdlib.h>
#include <stdint.h>

#define SI539XSEQ_SEQ_MEM        0x0000  /* 1024 x 32 command words */
#define SI539XSEQ_SEQ_DEPTH      1024
#define SI539XSEQ_ID             0x1000
#define SI539XSEQ_CONTROL        0x1004
#define SI539XSEQ_STATUS         0x1008
#define SI539XSEQ_SCLK_DIV       0x100C  /* SCLK half-period in clk cycles;
                                            >= 3 at 100 MHz (chip max 20 MHz).
                                            Not enforced: verify after changing */
#define SI539XSEQ_CS_GAP         0x1018  /* CSb high time between frames in clk
                                            cycles, plus 3; >= 7 at 100 MHz (chip
                                            min 95 ns). Not enforced */
#define SI539XSEQ_SEQ_INDEX      0x1010  /* current entry, or where it stopped */
#define SI539XSEQ_POLL_COUNT     0x1014  /* 31 bits; 0 = no pass yet; wraps to 1 */
#define SI539XSEQ_POLL_MEM       0x1100  /* 64 x 32 command words */
#define SI539XSEQ_POLL_DEPTH     64

#define SI539XSEQ_ID_VALUE       0x53690100  /* "Si", version 1.00 */

/* CONTROL: always read-modify-write so bits 8-10 are kept */
#define SI539XSEQ_CTL_SEQ_GO        (1u << 0)   /* self-clearing, reads 0 */
#define SI539XSEQ_CTL_POLL_EN       (1u << 1)
#define SI539XSEQ_CTL_CHIP_RESET    (1u << 8)   /* 1 = RSTb held low */
#define SI539XSEQ_CTL_CLKBUF_DIS    (1u << 9)
#define SI539XSEQ_CTL_LVLSHIFT_DIS  (1u << 10)

/* STATUS */
#define SI539XSEQ_STS_SEQ_BUSY      (1u << 0)
#define SI539XSEQ_STS_SEQ_DONE      (1u << 1)
#define SI539XSEQ_STS_POLL_BUSY     (1u << 2)
#define SI539XSEQ_STS_PIN_LOL       (1u << 8)   /* raw pin levels; chip pins */
#define SI539XSEQ_STS_PIN_LOS_XAXB  (1u << 9)   /* are active low            */
#define SI539XSEQ_STS_PIN_INTR      (1u << 10)

/*
 * Command words: [31:28] op, [27:24] page (ignored by the engine; kept as a
 * note for software), [23:16] register, [15:8] read result, [7:0] data.
 * The engine does not manage the page: every sequence and every poll program
 * must start with si539xSeqPage(), and include one wherever the page changes.
 * Addresses below are the full 0xPPRR form; the page part is only recorded.
 */
#define SI539XSEQ_OP_END    0u
#define SI539XSEQ_OP_WRITE  1u
#define SI539XSEQ_OP_READ   2u
#define SI539XSEQ_OP_DELAY  3u

#define SI539x_PAGE(page) \
    ((SI539XSEQ_OP_WRITE << 28) | ((uint32_t)((page) & 0xF) << 24) | (0x01u << 16) | (page))

#define SI539x_WRITE(addr, data) \
    ((SI539XSEQ_OP_WRITE << 28) | ((uint32_t)((addr) & 0xFFF) << 16) | (data))

#define SI539x_READ(addr, note) \
    ((SI539XSEQ_OP_READ << 28) | ((uint32_t)((addr) & 0xFFF) << 16) | (note))

#define SI539x_DELAY(ms) \
    ((SI539XSEQ_OP_DELAY << 28) | (((ms) * SI539x_TICKS_PER_MS) & 0x0FFFFFFF))

// sequencer driven by ublaze/AXI clock
#define SI539x_TICKS_PER_MS (XPAR_CPU_CORE_CLOCK_FREQ_HZ / 1000u)

// "destination" sequence
#define SI539x_DEST_MAIN 0x10
#define SI539x_DEST_POLL 0x20
#define SI539x_MAIN(ch) SI539x_DEST_MAIN | ((ch)&0x1)
#define SI539x_POLL(ch) SI539x_DEST_POLL | ((ch)&0x1)

// load a concrete sequence
int si539xLoadSeq(unsigned dest, const uint32_t* cmds, size_t ncmds);

enum si539xAction {
    si539xActionReg=6,
    si539xActionDelay,
    si539xActionPage,
};

struct si539xSetting {
    enum si539xAction action: 4;
    unsigned addr: 12;
    unsigned mask: 8;
    unsigned value: 8;
};
#define SI539x_SEQ_PAGE(page) {8, page, 0, 0}
#define SI539x_SEQ_DELAY(millisec) {7, millisec, 0, 0}
#define SI539x_SEQ_REG(addr, mask, value) {6, addr, mask, value}

/** read an array of register actions, load a sequence of reads or writes
 *
 * When write=0, Load a program which reads the current value of all setting registers.
 *
 * When write=1, Load a program which writes all setting registers.
 * The value written is taken from the initials array, modified by the mask & value
 * from the corresponding settings element.
 * If provided, the overrides array is searched for a matching.
 * If found, the mask & value are applied as well.
 *
 * @params[in] dest SI539x_MAIN(ch) or SI539x_POLL(ch)
 * @params[in] write 0 to read back, 1 to write
 * @params[in] initials When writing, pointer to list of initial register values.
 *                      Must have same size as settings.
 * @params[in] settings List of registers.
 * @params[in] nsettings Length of initials and settings arrays.
 * @params[in] overrides When writing.  NULL or a list of additional settings
 * @params[in] noverrides Length of overrides
 */
int si539xCompileSeq(unsigned dest, bool write,
                     const uint8_t *initials,
                     const struct si539xSetting* settings, size_t nsettings,
                     const struct si539xSetting* overrides, size_t noverrides);
// Start/Stop a sequencer
int si539xStartStop(unsigned dest, unsigned start);
// read result value from index
uint8_t si539xReadSeq(unsigned dest, size_t idx);
uint32_t si539xReadSeqInstr(unsigned dest, size_t idx);
// Test if sequencer is idle.
// returns 1 if idle, 0 if busy, negative on error
int si539xIsIdle(unsigned dest);

#define SI539XSEQ_END 0u

/* Fields of a word read back after a READ has run */
#define SI539XSEQ_WORD_REG(w)       (((w) >> 16) & 0xFF)
#define SI539XSEQ_WORD_PAGE(w)      (((w) >> 24) & 0xF)   /* software's note */
#define SI539XSEQ_WORD_RESULT(w)    (((w) >> 8) & 0xFF)
#define SI539XSEQ_WORD_EXPECTED(w)  ((w) & 0xFF)

/*
 * Driver (ospreySi539xSeq.c). 'ch' selects the engine: 0 = jtrSeq1, 1 = jtrSeq2.
 * Timeouts are in microseconds. Functions returning int give 0 on success or a
 * negative SI539XSEQ_ERR_ code.
 */
#define SI539XSEQ_COUNT          2

#define SI539XSEQ_ERR_CHANNEL   -1  /* no such engine */
#define SI539XSEQ_ERR_BUSY      -2  /* previous sequence still running */
#define SI539XSEQ_ERR_LENGTH    -3  /* list longer than the memory */
#define SI539XSEQ_ERR_TIMEOUT   -4  /* sequence or poll pass did not finish */
#define SI539XSEQ_ERR_INVALID   -5  /* invalid si539xSetting */

int      si539xSeqPresent(unsigned ch);
uint32_t si539xSeqGetReg(unsigned ch, unsigned offset);
void     si539xSeqSetReg(unsigned ch, unsigned offset, uint32_t value);
void     si539xSeqControl(unsigned ch, uint32_t setBits, uint32_t clearBits);
uint32_t si539xSeqClocksPerUs(void);
void     si539xSeqShowStatus(unsigned ch);

#endif /* OSPREY_SI539X_SEQ_H */
