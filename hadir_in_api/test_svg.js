const sharp = require('sharp');
const fs = require('fs');

async function test() {
    const templateBuffer = await sharp({
        create: {
            width: 800,
            height: 400,
            channels: 4,
            background: { r: 100, g: 100, b: 100, alpha: 1 } // gray bg
        }
    }).png().toBuffer();

    const fontSize = 48;
    const color = 'white';
    const nameX = 50;
    const nameY = 50;
    const displayName = "Ahmad Fathan";

    const svgWidth = 700;
    const svgHeight = 100;

    const svgText = Buffer.from(
        `<svg xmlns="http://www.w3.org/2000/svg" width="${svgWidth}" height="${svgHeight}">`
        + `<text x="0" y="${fontSize}" font-family="Arial, Helvetica, sans-serif" font-size="${fontSize}" fill="${color}" font-weight="bold">${displayName}</text>`
        + `</svg>`
    );

    const composites = [{ input: svgText, left: nameX, top: nameY }];

    try {
        const result = await sharp(templateBuffer).composite(composites).png().toBuffer();
        fs.writeFileSync('test_svg_output.png', result);
        console.log("Success! File saved to test_svg_output.png");
    } catch(err) {
        console.error("Error compositing:", err);
    }
}
test();
