#import imageio
from PIL import Image
import numpy as np

## Filter for one pixel
def pix_filter ( coeffs, pos_x, pos_y, src_im ):
    
    size_x, size_y = coeffs.shape

    filtered = 0;
    
    for local_x in range(0, size_x):
        
        for local_y in range(0, size_y):

            filtered += coeffs[local_x][local_y] * src_im.getpixel((pos_x+local_x, pos_y+local_y))

    return max(0,filtered)


## Main
src_name = 'source_240x240_gray'
src_im = Image.open(src_name + '.png')

size_x, size_y = src_im.size

dst_name = 'dest_240x240_gray'
dst_im   = Image.new('L', (size_x, size_y))

coeffs   = np.array([[ 0, -1,  0], [-1,  4, -1], [ 0, -1,  0]])

# Loop over all pixels in destination image and perform filtering
for pos_x in range(0, size_x-2):
    
    for pos_y in range(0, size_y-2):
        
        dst_im.putpixel( (pos_x, pos_y), pix_filter(coeffs, pos_x, pos_y, src_im) )

src_im.show()
dst_im.show()

## Write source data in 16-bit words. Each word contains two monochrome pixels.
#  Bytes are arranged in big endian format: word = [ px[n+1], px[n] ]
src_pix = src_im.getdata()

with open(src_name + '.dmem', 'w') as f:
    it = iter(src_pix)
    for px in it:
        helper    = hex(px)[2:].zfill(2)
        formatted = hex(next(it))[2:].zfill(2) + helper
        f.write("%s\n" % formatted)


