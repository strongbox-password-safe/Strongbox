# Delete the comments
cat StrongBox/Base.lproj/Localizable.strings | sed '/^\\\*/ d' | sed '/^\/\/*/ d' > temp

# Delete everything up to and including the equals sign
cat temp | sed s/.*\=// > temp.1

# Delete the remaining quotes and semi-colon
cat temp.1 | sed s/\"// | sed s/\"// | sed s/\;// > temp.2

# Use wc to sount and spit out the number of words
wc -w < temp.2 

# Remove the temp files
rm -f temp
rm -f temp.1
rm -f temp.2
