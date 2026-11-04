/*
 * ospreySi539xSeq.h -- register map and command encoders for the
 * ospreySi539xSeq SPI sequencer (one instance per Si539x chip).
 * Offsets are bytes from the instance's AXI base address.
 */
#ifndef OSPREY_SI539X_SEQ_H
#define OSPREY_SI539X_SEQ_H

#include <stdint.h>

#define SI539XSEQ_SEQ_MEM        0x0000  /* 1024 x 32 command words */
#define SI539XSEQ_SEQ_DEPTH      1024
#define SI539XSEQ_ID             0x1000
#define SI539XSEQ_CONTROL        0x1004
#define SI539XSEQ_STATUS         0x1008
#define SI539XSEQ_SCLK_DIV       0x100C  /* SCLK half-period in clk cycles;
                                            >= 3 at 100 MHz (chip max 20 MHz).
                                            Not enforced: verify after changing */
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

static inline uint32_t si539xSeqWrite(uint16_t addr, uint8_t data)
{
    return (SI539XSEQ_OP_WRITE << 28) | ((uint32_t)(addr & 0xFFF) << 16) | data;
}
static inline uint32_t si539xSeqRead(uint16_t addr, uint8_t expected)
{
    return (SI539XSEQ_OP_READ << 28) | ((uint32_t)(addr & 0xFFF) << 16) | expected;
}
static inline uint32_t si539xSeqPage(uint8_t page)
{
    return (SI539XSEQ_OP_WRITE << 28) | ((uint32_t)(page & 0xF) << 24) | (0x01u << 16) | page;
}
/*
 * DELAY counts AXI clock cycles. Convert with clk_hz from xparameters.h
 * (the MicroBlaze runs on the same 100 MHz clock). Max 0x0FFFFFFF counts.
 */
static inline uint32_t si539xSeqDelay(uint32_t clocks)
{
    return (SI539XSEQ_OP_DELAY << 28) | (clocks & 0x0FFFFFFF);
}
#define SI539XSEQ_END 0u

/* Fields of a word read back after a READ has run */
#define SI539XSEQ_WORD_REG(w)       (((w) >> 16) & 0xFF)
#define SI539XSEQ_WORD_PAGE(w)      (((w) >> 24) & 0xF)   /* software's note */
#define SI539XSEQ_WORD_RESULT(w)    (((w) >> 8) & 0xFF)
#define SI539XSEQ_WORD_EXPECTED(w)  ((w) & 0xFF)

#endif /* OSPREY_SI539X_SEQ_H */
