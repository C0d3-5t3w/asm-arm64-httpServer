document.addEventListener('DOMContentLoaded', function() {
    let clickCount = 0;
    const button = document.getElementById('clickMe');
    const counter = document.getElementById('clickCount');
    
    button.addEventListener('click', function() {
        clickCount++;
        counter.textContent = `Button has been clicked ${clickCount} time${clickCount !== 1 ? 's' : ''}.`;
        
        // Change button color randomly on click
        const randomColor = '#' + Math.floor(Math.random()*16777215).toString(16);
        button.style.backgroundColor = randomColor;
    });
    
    // Add a message to the console
    console.log('Page loaded and served by ARM64 assembly HTTP server!');
});
