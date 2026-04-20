// Test Jimp v1 font loading with local path
const { Jimp, loadFont } = require('jimp');
const path = require('path');

async function test() {
  // Find font files
  const pluginDir = path.dirname(require.resolve('@jimp/plugin-print'));
  console.log('plugin-print dir:', pluginDir);
  
  const fs = require('fs');
  function walkDir(dir, level = 0) {
    if (level > 3) return;
    if (!fs.existsSync(dir)) return;
    const items = fs.readdirSync(dir);
    items.forEach(item => {
      const fullPath = path.join(dir, item);
      const stat = fs.statSync(fullPath);
      const indent = '  '.repeat(level);
      if (stat.isDirectory()) {
        console.log(indent + '[DIR]', item);
        walkDir(fullPath, level + 1);
      } else {
        console.log(indent + item);
      }
    });
  }
  
  walkDir(pluginDir);
}

test().catch(e => console.log('Error:', e.message));
