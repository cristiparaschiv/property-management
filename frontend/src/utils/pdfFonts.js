/**
 * Font registration for jsPDF with Romanian character support
 */

// Function to register Roboto font with jsPDF
export const registerRobotoFont = async (doc) => {
  try {
    // Fetch the TTF font from Google Fonts CDN (full font with all characters including Romanian)
    const response = await fetch('https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Me5Q.ttf');
    if (!response.ok) {
      throw new Error('Failed to fetch font');
    }

    const arrayBuffer = await response.arrayBuffer();
    const base64 = arrayBufferToBase64(arrayBuffer);

    // Register the font with jsPDF
    doc.addFileToVFS('Roboto-Regular.ttf', base64);
    doc.addFont('Roboto-Regular.ttf', 'Roboto', 'normal');

    // Also fetch bold variant
    const boldResponse = await fetch('https://fonts.gstatic.com/s/roboto/v30/KFOlCnqEu92Fr1MmWUlvAw.ttf');
    if (boldResponse.ok) {
      const boldBuffer = await boldResponse.arrayBuffer();
      const boldBase64 = arrayBufferToBase64(boldBuffer);
      doc.addFileToVFS('Roboto-Bold.ttf', boldBase64);
      doc.addFont('Roboto-Bold.ttf', 'Roboto', 'bold');
    }

    return true;
  } catch (error) {
    console.warn('Could not load Roboto font, falling back to Helvetica:', error);
    return false;
  }
};

// Helper function to convert ArrayBuffer to Base64
function arrayBufferToBase64(buffer) {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export default { registerRobotoFont };
