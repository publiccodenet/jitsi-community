
include config.unix

CFLAGS+=-I$(LUA_INCDIR)

INSTALL_DATA=install -m644
TARGET?=../util/

ALL=hashes.so

ifdef RANDOM
ALL+=crand.so
endif

.PHONY: all install clean
.SUFFIXES: .c .o .so

all: $(ALL)

install: $(ALL)
	$(INSTALL_DATA) $? $(TARGET)

clean:
	rm -f $(ALL) $(patsubst %.so,%.o,$(ALL))

hashes.so: LDLIBS+=$(OPENSSL_LIBS)

%.so: %.o
	$(LD) $(LDFLAGS) -o $@ $^ $(LDLIBS)
