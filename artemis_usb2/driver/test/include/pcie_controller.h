#ifndef __PCIE_H__
#define __PCIE_H__




class PCIE {

private:
    int fn;
    bool debug;

public:
    PCIE(char * filename);
    ~PCIE();
    void enable_debug(bool enable);
    void write_register(unsigned int address, unsigned int value);
    void write_command(unsigned int address, unsigned int value, unsigned int device_address);

    ssize_t read_periph_data(unsigned int address, unsigned char * buf, unsigned int count);
};

#endif //__PCIE_H__
