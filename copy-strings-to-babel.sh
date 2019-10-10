#!/bin/sh

# Base Localizable.strings

cp StrongBox/en-US.lproj/*.strings ../strongbox-babel/StrongBox/
cp StrongBox\ Auto\ Fill/en-US.lproj/*.strings ../strongbox-babel/StrongBox\ Auto\ Fill/

cp StrongBox/Base.lproj/Localizable.strings ../strongbox-babel/StrongBox/

# German

cp StrongBox/de.lproj/*.strings ../strongbox-babel/StrongBox/de/
cp StrongBox/CustomCells/de.lproj/*.strings ../strongbox-babel/StrongBox/de/CustomCells/
cp StrongBox\ Auto\ Fill/de.lproj/*.strings ../strongbox-babel/StrongBox\ Auto\ Fill/de/

# Russian

cp StrongBox/ru.lproj/*.strings ../strongbox-babel/StrongBox/ru/
cp StrongBox/CustomCells/ru.lproj/*.strings ../strongbox-babel/StrongBox/ru/CustomCells/
cp StrongBox\ Auto\ Fill/ru.lproj/*.strings ../strongbox-babel/StrongBox\ Auto\ Fill/ru/
