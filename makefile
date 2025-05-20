BINARY = hello
MAIN = main
BIN = bin
obj = $(MAIN).o


build:
	@as -o $(obj) $(MAIN).asm
	@ld -o $(BINARY) $(obj) -lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -e _$(MAIN) -arch arm64
	@mkdir -p $(BIN)
	@mv $(BINARY) $(BIN)/$(BINARY)
	@mv $(obj) $(BIN)/$(obj)
	@cp -r *.html $(BIN)
	@cp -r *.js $(BIN)
	@cp -r *.css $(BIN)

clean:
	@rm -rf $(BIN)

run:
	@cd $(BIN) && ./$(BINARY)

.PHONY: build clean run
