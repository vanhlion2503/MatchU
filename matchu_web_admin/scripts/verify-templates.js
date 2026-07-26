const fs = require('fs');
const path = require('path');
const ejs = require('ejs');

const viewsRoot = path.join(__dirname, '..', 'src', 'views');
const files = [];

function collectTemplates(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) collectTemplates(fullPath);
    else if (entry.name.endsWith('.ejs')) files.push(fullPath);
  }
}

collectTemplates(viewsRoot);
for (const file of files) {
  ejs.compile(fs.readFileSync(file, 'utf8'), { filename: file });
}
console.log(`Verified ${files.length} EJS templates.`);
