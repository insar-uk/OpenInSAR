// add a hello world div to the page
console.log("Hello World!");

// Wait for document to load
document.addEventListener("DOMContentLoaded", function(event) {
    console.log("DOM fully loaded and parsed");

    
// Get body element
var body = document.getElementsByTagName("body")[0];

// Create a new div element
var newDiv = document.createElement("div");

// Give the new div some content
var newContent = document.createTextNode("Hello World!");

// Add the text node to the newly created div
newDiv.appendChild(newContent);

// Add the newly created element and its content into the DOM
body.appendChild(newDiv);

});
