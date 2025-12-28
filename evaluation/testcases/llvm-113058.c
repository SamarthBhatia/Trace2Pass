#include <riscv_vector.h>
int printf(const char *, ...);

#define dataLen 12
int8_t data_mask[dataLen];
uint8_t data_idx[dataLen];
uint8_t a[dataLen];
uint8_t b[dataLen];
uint8_t c[dataLen];

void initialize(){
  int8_t tmp_mask[dataLen] = {1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, };
  uint8_t tmp_idx[dataLen] = {0, 0, 3, 8, 4, 6, 11, 5, 9, 4, 10, 6, };
  uint8_t tmp_a[dataLen] = {165, 94, 49, 133, 214, 73, 163, 67, 191, 227, 214, 101, };
  uint8_t tmp_b[dataLen] = {138, 171, 158, 140, 240, 123, 237, 53, 70, 254, 196, 240, };
  for (int i = 0; i < dataLen; ++i) { data_mask[i] = tmp_mask[i]; }
  for (int i = 0; i < dataLen; ++i) { data_idx[i] = tmp_idx[i]; }
  for (int i = 0; i < dataLen; ++i) { a[i] = tmp_a[i]; }
  for (int i = 0; i < dataLen; ++i) { b[i] = tmp_b[i]; }
  for (int i = 0; i < dataLen; ++i) { c[i] = 0; }
}

int main(){
  initialize();
  int placeholder0 = dataLen;
  int8_t* ptr_mask = data_mask;
  uint8_t* ptr_idx = data_idx;
  uint8_t* ptr_a = a;
  uint8_t* ptr_b = b;
  uint8_t* ptr_c = c;
  for (size_t vl; placeholder0 > 0; placeholder0 -= vl){
    vl = __riscv_vsetvl_e8m4(placeholder0);
    vbool2_t vmask= __riscv_vmseq_vx_i8m4_b2(__riscv_vle8_v_i8m4(ptr_mask, vl), 1, vl);
    vuint8m4_t va = __riscv_vle8_v_u8m4_m(vmask, ptr_a, vl);
    vuint8m4_t vb = __riscv_vle8_v_u8m4_m(vmask, ptr_b, vl);
    va = __riscv_vasubu_vv_u8m4_m(vmask, va, vb, __RISCV_VXRM_RNU, vl);
    __riscv_vsuxei8_v_u8m4(ptr_c, __riscv_vle8_v_u8m4(ptr_idx, vl), va, vl);
    // __riscv_vsoxei8_v_u8m4(ptr_c, __riscv_vle8_v_u8m4(ptr_idx, vl), va, vl); // the same error
    ptr_mask += vl; ptr_idx += vl;
    ptr_a += vl; ptr_b += vl; ptr_c += vl;
  }
  if(c[data_idx[0]] != 14)  __builtin_abort(); // roundoff_unsigned(165-138, 1)
  return 0;
}
