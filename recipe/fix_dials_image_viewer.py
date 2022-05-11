'''
Tool for fixing dials.image_viewer
'''
import sys

if __name__ == '__main__':
  # assume argument is the path to dials.image_viewer
  # ${PREFIX}/bin/dials.image_viewer
  lines = []
  with open(sys.argv[1]) as f:
    lines = f.readlines()

  with open(sys.argv[1], 'w') as f:
    for line in lines:
      print(line.strip())
      if line.strip().endswith('python'):
        print('before', line.strip())
        line = line.replace('python', 'pythonw')
        print('after', line.strip())
      f.write(line)
