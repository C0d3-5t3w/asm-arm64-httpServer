.section __DATA,__data
    // HTTP responses and headers
    http_ok: .ascii "HTTP/1.1 200 OK\r\n"
    http_ok_len = . - http_ok
    
    content_type_html: .ascii "Content-Type: text/html\r\n\r\n"
    content_type_html_len = . - content_type_html
    
    content_type_css: .ascii "Content-Type: text/css\r\n\r\n"
    content_type_css_len = . - content_type_css
    
    content_type_js: .ascii "Content-Type: application/javascript\r\n\r\n"
    content_type_js_len = . - content_type_js
    
    not_found: .ascii "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\n404 Not Found\r\n"
    not_found_len = . - not_found
    
    // File paths
    index_path: .ascii "index.html\0"
    css_path: .ascii "styles.css\0"
    js_path: .ascii "script.js\0"
    
    // Socket configuration
    server_addr:
        .short 0x0200         // AF_INET
        .short 0x5000         // Port 80 in network byte order (big-endian)
        .quad  0              // INADDR_ANY
    
    // Buffer for HTTP request
    .align 4
    request_buffer: .space 2048
    file_buffer: .space 8192
    
    // Error messages
    socket_error_msg: .ascii "Error creating socket\n"
    socket_error_len = . - socket_error_msg
    
    bind_error_msg: .ascii "Error binding socket\n"
    bind_error_len = . - bind_error_msg
    
    listen_error_msg: .ascii "Error listening on socket\n"
    listen_error_len = . - listen_error_msg

.section __TEXT,__text
    .global _main

_main:
    // Create socket
    mov x0, #2                // AF_INET
    mov x1, #1                // SOCK_STREAM
    mov x2, #0                // Protocol 0
    mov x16, #97              // socket syscall
    svc #0x80
    
    cmp x0, #0                // Check if socket creation failed
    blt socket_error
    
    mov x12, x0               // Save socket fd to x12
    
    // Bind socket
    mov x0, x12               // Socket fd
    adrp x1, server_addr@PAGE // Server address structure
    add x1, x1, server_addr@PAGEOFF
    mov x2, #16               // Length of address structure
    mov x16, #104             // bind syscall
    svc #0x80
    
    cmp x0, #0                // Check if bind failed
    blt bind_error
    
    // Listen for connections
    mov x0, x12               // Socket fd
    mov x1, #5                // Backlog
    mov x16, #106             // listen syscall
    svc #0x80
    
    cmp x0, #0                // Check if listen failed
    blt listen_error
    
accept_loop:
    // Accept connection
    mov x0, x12               // Socket fd
    mov x1, #0                // NULL client address
    mov x2, #0                // NULL address length
    mov x16, #30              // accept syscall
    svc #0x80
    
    cmp x0, #0                // Check if accept failed
    blt accept_loop
    
    mov x13, x0               // Save client socket fd to x13
    
    // Read request
    mov x0, x13               // Client socket fd
    adrp x1, request_buffer@PAGE
    add x1, x1, request_buffer@PAGEOFF
    mov x2, #2048             // Buffer size
    mov x16, #3               // read syscall
    svc #0x80
    
    // Parse request to determine file path
    adrp x1, request_buffer@PAGE
    add x1, x1, request_buffer@PAGEOFF
    
    // Default to index.html
    adrp x2, index_path@PAGE
    add x2, x2, index_path@PAGEOFF
    mov x14, #0               // 0 = HTML, 1 = CSS, 2 = JS
    
    // Check for "/styles.css"
    adrp x3, css_path@PAGE
    add x3, x3, css_path@PAGEOFF
    bl check_path
    cmp x0, #1
    beq serve_css
    
    // Check for "/script.js"
    adrp x3, js_path@PAGE
    add x3, x3, js_path@PAGEOFF
    bl check_path
    cmp x0, #1
    beq serve_js
    
    // Serve index.html by default
serve_html:
    adrp x2, index_path@PAGE
    add x2, x2, index_path@PAGEOFF
    mov x14, #0               // 0 = HTML
    b serve_file
    
serve_css:
    adrp x2, css_path@PAGE
    add x2, x2, css_path@PAGEOFF
    mov x14, #1               // 1 = CSS
    b serve_file
    
serve_js:
    adrp x2, js_path@PAGE
    add x2, x2, js_path@PAGEOFF
    mov x14, #2               // 2 = JS
    
serve_file:
    // Send HTTP 200 OK
    mov x0, x13               // Client socket fd
    adrp x1, http_ok@PAGE
    add x1, x1, http_ok@PAGEOFF
    mov x2, http_ok_len
    mov x16, #4               // write syscall
    svc #0x80
    
    // Send Content-Type based on file type
    mov x0, x13               // Client socket fd
    cmp x14, #1
    beq send_css_header
    cmp x14, #2
    beq send_js_header
    
    // HTML header (default)
    adrp x1, content_type_html@PAGE
    add x1, x1, content_type_html@PAGEOFF
    mov x2, content_type_html_len
    b send_header
    
send_css_header:
    adrp x1, content_type_css@PAGE
    add x1, x1, content_type_css@PAGEOFF
    mov x2, content_type_css_len
    b send_header
    
send_js_header:
    adrp x1, content_type_js@PAGE
    add x1, x1, content_type_js@PAGEOFF
    mov x2, content_type_js_len
    
send_header:
    mov x16, #4               // write syscall
    svc #0x80
    
    // Open and read file
    mov x0, x2                // File path
    mov x1, #0                // O_RDONLY
    mov x16, #5               // open syscall
    svc #0x80
    
    cmp x0, #0                // Check if file open failed
    blt send_not_found
    
    mov x14, x0               // Save file fd
    
    // Read file content
    mov x0, x14               // File fd
    adrp x1, file_buffer@PAGE
    add x1, x1, file_buffer@PAGEOFF
    mov x2, #8192             // Buffer size
    mov x16, #3               // read syscall
    svc #0x80
    
    mov x15, x0               // Save bytes read
    
    // Close file
    mov x0, x14
    mov x16, #6               // close syscall
    svc #0x80
    
    // Send file content
    mov x0, x13               // Client socket fd
    adrp x1, file_buffer@PAGE
    add x1, x1, file_buffer@PAGEOFF
    mov x2, x15               // Bytes read from file
    mov x16, #4               // write syscall
    svc #0x80
    
    b close_client
    
send_not_found:
    // Send 404 Not Found
    mov x0, x13               // Client socket fd
    adrp x1, not_found@PAGE
    add x1, x1, not_found@PAGEOFF
    mov x2, not_found_len
    mov x16, #4               // write syscall
    svc #0x80
    
close_client:
    // Close client socket
    mov x0, x13
    mov x16, #6               // close syscall
    svc #0x80
    
    b accept_loop             // Loop back to accept more connections

// Function to check if request contains a specific path
// x1 = request buffer, x3 = path to check
// Returns: x0 = 1 if path found, 0 otherwise
check_path:
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    
    mov x19, x1               // Save request buffer
    mov x20, x3               // Save path to check
    
    // Look for GET /path
    mov x21, #0               // Current position in request
    
check_loop:
    ldrb w5, [x19, x21]       // Load byte from request
    cmp w5, #0                // Check for null terminator
    beq check_not_found
    
    cmp w5, #0x20             // Check for space
    bne check_next_byte
    
    add x21, x21, #1          // Move past space
    ldrb w5, [x19, x21]
    cmp w5, #0x2F             // Check for '/'
    bne check_next_byte
    
    // Found "GET /" - now check if next chars match path
    add x21, x21, #1          // Move past '/'
    mov x22, #0               // Position in path
    
match_loop:
    ldrb w6, [x20, x22]       // Load byte from path
    cmp w6, #0                // End of path?
    beq match_found
    
    ldrb w5, [x19, x21]       // Load byte from request
    cmp w5, #0x20             // Space or end of line?
    beq check_not_found
    cmp w5, #0x0D             // CR?
    beq check_not_found
    cmp w5, #0x0A             // LF?
    beq check_not_found
    
    cmp w5, w6                // Do characters match?
    bne check_not_found
    
    add x21, x21, #1          // Next request byte
    add x22, x22, #1          // Next path byte
    b match_loop
    
match_found:
    mov x0, #1                // Return 1 (found)
    b check_return
    
check_not_found:
    mov x0, #0                // Return 0 (not found)
    
check_next_byte:
    add x21, x21, #1          // Move to next byte
    b check_loop
    
check_return:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ret

socket_error:
    // Print socket error message
    mov x0, #2                // File descriptor 2 (stderr)
    adrp x1, socket_error_msg@PAGE
    add x1, x1, socket_error_msg@PAGEOFF
    mov x2, socket_error_len
    mov x16, #4               // write syscall
    svc #0x80
    b exit_error

bind_error:
    // Print bind error message
    mov x0, #2                // File descriptor 2 (stderr)
    adrp x1, bind_error_msg@PAGE
    add x1, x1, bind_error_msg@PAGEOFF
    mov x2, bind_error_len
    mov x16, #4               // write syscall
    svc #0x80
    b exit_error

listen_error:
    // Print listen error message
    mov x0, #2                // File descriptor 2 (stderr)
    adrp x1, listen_error_msg@PAGE
    add x1, x1, listen_error_msg@PAGEOFF
    mov x2, listen_error_len
    mov x16, #4               // write syscall
    svc #0x80
    b exit_error
    
exit_error:
    // Exit with error code
    mov x0, #1                // Exit code 1
    mov x16, #1               // exit syscall
    svc #0x80