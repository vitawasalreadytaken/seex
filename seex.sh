#!/bin/sh
# The MIT License
# 
# Copyright (c) 2011-2013 Vita Smid <me@ze.phyr.us>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


# A function to print help.
help() {
	cat <<-ENDOFHELP
		seex is a self-expanding archive creator. It can pack up a file or directory
		into a neat shell script that you can later unpack just by executing it.

		Usage:
		  $0 [OPTIONS] <file/directory to be packed>

		Available options:
		  -o, --output       Path where the resulting archive will be created
		                     (the default is the path of the source file/directory
		                     with .sh suffix).
		  -c, --compressor   Path to compressing program (the default is /bin/gzip).
		                     The compressor MUST print compressed data on stdout.
		  -p, --options      Custom options that will be passed to the compressor
		                     (the default is --stdout).
		                     They must be entered as a single string, e.g. -o '-v -9'
		  -h, --help         Print this message.

		seex was written by Vita Smid <me@ze.phyr.us> in MMXI and is distributed
		under the MIT license.
	ENDOFHELP
}

# Clean up the temporary file and quietly exit.
cleanUp() {
	if [ ! -z "$tarfile" -a -e "$tarfile" ]; then
		rm $tarfile
	fi
	exit
}


# Set default options.
output=
compressor=/bin/gzip
compressorOpts=--stdout
src=

# If no arguments are supplied, we just print the help message and exit.
if [ $# -eq 0 ]; then
	help
	exit 1
fi

# Parse command line arguments.
while [ $# -gt 0 ]; do
	case $1 in
		-h|--help)
			help
			exit 0
			;;

		-o|--output)
			shift
			output=$1
			;;

		-p|--options)
			shift
			compressorOpts=$1
			if [ -z "$compressorOpts" ]; then
				echo 'Error: no compression options given!' >&2
				exit 2
			fi
			;;

		-c|--compressor)
			shift
			compressor=$1
			if [ -z "$compressor" ]; then
				echo 'Error: no path to compressor given!' >&2
				exit 3
			elif [ ! -x "$compressor" ]; then
				echo 'Error: `'$compressor'` is not executable!' >&2
				exit 4
			fi
			;;

		*)
			# Anything we don't know is presumably the path to the
			# file/directory to be packed. However, if we already have
			# that path, there must have been at least one unknown argument.
			if [ -z "$src" ]; then
				src=$1
			else
				echo 'Error: unknown argument:' $1 >&2
				exit 5
			fi
			;;
	esac

	shift
done

# If $src is empty after the parsing, no path for packing could have
# been specified. If the path has been provided, we check that it
# exists and is readable. 
if [ -z "$src" ]; then
	echo 'Error: no file or directory to pack!' >&2
	exit 6
elif [ ! -r "$src" ]; then
	echo 'Error: `'$src'` does not exist or is not readable.' >&2
	exit 7
fi

# If no output path was given, we use the path of the source + .sh.
# We must take care to strip the possible trailing slash before
# appending the suffix.
if [ -z "$output" ]; then
	output=${src%/}.sh
fi

# Make sure we clean up after ourselves when we receive a signal.
trap cleanUp HUP INT TERM

# Now we're finally ready to roll. We tar the source and gather information
# about the archive we are about to produce.
tarfile=`tempfile`
tar cf $tarfile $src
size=`du -sh $src | cut -f1`
hash=`sha1sum $tarfile | cut -c1-40`
info="I was packed by `whoami`@`hostname` with $compressor $compressorOpts on `date`. When unpacked, I take up about $size."

# Read ourselves, substitute variables in the template and write it to $output.
awk <$0 > $output '
template {
	sub(/<HASH>/, "'$hash'")
	sub(/<INFO>/, "'"$info"'")
	sub(/<COMPRESSOR>/, "'"$compressor"'")
	print
}
/<TEMPLATE>\s*$/ {
	template = 1
}
'

# Compress the tar archive and add it to $output. Make $output executable.
$compressor $compressorOpts $tarfile >> $output
chmod +x $output

# Clean up & au revoir.
cleanUp




###############################################################################
###############################################################################
###############################################################################
# The self-expanding script template follows after this tag: <TEMPLATE>
#!/bin/sh

help() {
	cat <<-ENDOFHELP
		Hi. I am a self-expanding archive. Run me without arguments to unpack me.

		Usage:
		  $0 [OPTIONS]

		Available options:
		  -i, --info         Print basic information about the archive.
		  -l, --list         List all files and directories in the archive.
		  -o, --output       Specify target directory for unpacking (the default is
		                     the current working directory).
		  -d, --decompressor Path to decompressing program (the default is <COMPRESSOR>).
		                     The decompressor MUST print compressed data on stdout.
		  -p, --options      Custom options that will be passed to the decompressor
		                     (the default is --decompress --stdout).
		                     They must be entered as a single string, e.g. -o '-v -9'
		  -h, --help         Print this message.
	ENDOFHELP
}

# Clean up the temporary file and quietly exit.
cleanUp() {
	if [ ! -z "$tarfile" -a -e "$tarfile" ]; then
		rm $tarfile
	fi
	exit
}


# Set default options.
output=.
decompressor=<COMPRESSOR>
decompressorOpts='--decompress --stdout'
list=0

# Parse command line arguments.
while [ $# -gt 0 ]; do
	case $1 in
		-h|--help)
			help
			exit 0
			;;

		-i|--info)
			echo '<INFO>'
			exit 0
			;;

		-l|--list)
			list=1
			;;

		-o|--output)
			shift
			output=$1
			if [ -z "$output" ]; then
				echo 'Error: no output directory given!' >&2
				exit 1
			elif [ ! -d "$output" ]; then
				echo 'Error:' $output 'is not a directory!' >&2
				exit 2
			fi
			;;

		-p|--options)
			shift
			decompressorOpts=$1
			if [ -z "$decompressorOpts" ]; then
				echo 'Error: no decompression options given!' >&2
				exit 3
			fi
			;;

		-d|--decompressor)
			shift
			decompressor=$1
			if [ -z "$decompressor" ]; then
				echo 'Error: no path to decompressor given!' >&2
				exit 4
			elif [ ! -x "$decompressor" ]; then
				echo 'Error: `'$decompressor'` is not executable!' >&2
				exit 5
			fi
			;;

		*)
			echo 'Error: unknown argument:' $1 >&2
			exit 6
			;;
	esac

	shift
done

# Make sure we clean up after ourselves when we receive a signal.
trap cleanUp HUP INT TERM

# Get the data from ourselves and decompress it.
tarfile=`tempfile`
line=`grep --text --line-number --max-count=1 '<DATA>\s*$' $0 | cut --delimiter : --fields 1`
line=`expr $line + 1`
tail --lines=+$line $0 | $decompressor $decompressorOpts > $tarfile

# Now we can check the hash.
hash=`sha1sum $tarfile | cut --characters=1-40`
if [ "$hash" != "<HASH>" ]; then
	echo 'Warning: archive checksum does not match. The data might be corrupted!' >&2
fi

# And we finally open the archive. Either to list its contents or to actually
# unpack it into $output, depending on the user's choice.
if [ "$list" -eq 1 ]; then
	tar tf $tarfile
else
	cd $output
	tar xf $tarfile
fi

# Clean up & au revoir.
cleanUp


# The raw data follows after this tag: <DATA>
