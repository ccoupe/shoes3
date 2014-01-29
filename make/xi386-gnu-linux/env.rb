#
# Build a 32 bit Linux Shoes (from a 64 bit host)
# I have debian wheezy 7.1 i386 in an schroot directory. I built ruby
# in there (/usr/local) with the magic of X86_64 multi_arch.
# Currently, you must schroot and then do the rake. Also, in your
# schroot set the PATH to not include rvm.
#ENV['DEBUG'] = "true" # turns on the tracing log
#ENV['GTK'] = "gtk+-3.0" # pick this or "gtk+-2.0"
ENV['GTK'] = "gtk+-2.0"
# I don't recommend try to copy Gtk2 -it only works mysteriously
COPY_GTK = false 
ENV['GDB'] = "SureYouBetcha" # compile -g,  strip symbols when nil
# CHROOT = "/srv/chroot/deb386"
CHROOT = ""
# Where does ruby code live?
EXT_RUBY = "#{CHROOT}/usr"
SHOES_TGT_ARCH = 'i686-linux'
# Specify where the Target system binaries live. 
# Trailing slash is important.
TGT_SYS_DIR = "#{CHROOT}/"
# Setup some shortcuts for the library locations
arch = 'i386-linux-gnu'
uldir = "#{TGT_SYS_DIR}usr/lib"
ularch = "#{TGT_SYS_DIR}usr/lib/#{arch}"
larch = "#{TGT_SYS_DIR}lib/#{arch}"
# Set appropriately
CC = "gcc"

pkgruby ="#{EXT_RUBY}/lib/pkgconfig/ruby-1.9.pc"
pkggtk ="#{ularch}/pkgconfig/#{ENV['GTK']}.pc" 
CURL_LDFLAGS = `pkg-config --libs #{uldir}/pkgconfig/libcurl.pc`.strip
CURL_CFLAGS = `pkg-config --cflags #{uldir}/pkgconfig/libcurl.pc`.strip


file_list = %w{shoes/native/gtk.c shoes/http/curl.c} + ["shoes/*.c"]
SRC = FileList[*file_list]
OBJ = SRC.map do |x|
  x.gsub(/\.\w+$/, '.o')
end

ADD_DLL = []

# Hand code for your situation and Ruby purity. Mine is
# "Church of Whatever Works That I Can Understand"
def xfixip(path)
   path.gsub!(/-I\/usr\//, "-I#{TGT_SYS_DIR}usr/")
   path.gsub!(/x86_64-linux-gnu/,"i386-linux-gnu")
   return path
end

def xfixrvmp(path)
  # This is what happens when you don't cross compile ruby properly
  # like I told you to do. 
  #path.gsub!(/-I\/home\/ccoupe\/\.rvm/, "-I#{TGT_SYS_DIR}rvm")
  return path
end

#  fix up the -L paths for rvm ruby. Undo when not using an rvm ruby
def xfixrvml(path)
  #path.gsub!(/-L\/home\/ccoupe\/\.rvm/, "-L#{TGT_SYS_DIR}rvm")
  return path
end

# fixup the -L paths for gtk and other libs
def xfixil(path) 
  path.gsub!(/-L\/usr\/lib/, "-L#{TGT_SYS_DIR}usr/lib")
  return path
end

# Target environment
#CAIRO_CFLAGS = `pkg-config --cflags cairo`.strip
CAIRO_LIB = `pkg-config --libs cairo`.strip
#PANGO_CFLAGS = `pkg-config --cflags pango`.strip
PANGO_LIB = `pkg-config --libs pango`.strip

png_lib = 'png'

if ENV['DEBUG'] || ENV['GDB']
  LINUX_CFLAGS = " -g -O0"
else
  LINUX_CFLAGS = " -O -Wall"
end

LINUX_CFLAGS << " -DSHOES_GTK" 
LINUX_CFLAGS << " -DGTK3" unless ENV['GTK'] == 'gtk+-2.0'
LINUX_CFLAGS << " -I#{TGT_SYS_DIR}usr/include "
LINUX_CFLAGS << `pkg-config --cflags "#{pkgruby}"`.strip+" "
LINUX_CFLAGS << `pkg-config --cflags "#{pkggtk}"`.strip+" "
#LINUX_CFLAGS << xfixip(`pkg-config --cflags "#{ENV['GTK']}"`.strip)+" "
#LINUX_CFLAGS << " #{CAIRO_CFLAGS} #{PANGO_CFLAGS}"
LINUX_CFLAGS << " -I#{TGT_SYS_DIR}usr/include/ #{CURL_CFLAGS} " 


LINUX_LIB_NAMES = %W[ungif jpeg]

DLEXT = "so"
LINUX_LDFLAGS = "-fPIC -shared -L#{ularch} "
LINUX_LDFLAGS << `pkg-config --libs "#{pkggtk}"`.strip+" "
# use the ruby link info
RUBY_LDFLAGS = "-rdynamic -Wl,-export-dynamic "
RUBY_LDFLAGS << "-L#{EXT_RUBY}/lib -lruby "
RUBY_LDFLAGS << "-L#{ularch} -lrt -ldl -lcrypt -lm "
#LINUX_LDFLAGS << " #{CURL_LDFLAGS}"
#LINUX_LDFLAGS << " -L. -rdynamic -Wl,-export-dynamic"


LINUX_LIBS = LINUX_LIB_NAMES.map { |x| "-l#{x}" }.join(' ')

LINUX_LIBS << " #{RUBY_LDFLAGS} #{CAIRO_LIB} #{PANGO_LIB} #{CURL_LDFLAGS} "

# This could be precomputed by rake linux:setup:xxx 
# but for now make a hash of all the dep libs that need to be copied.
# and their location. This should be used in pre_build instead of 
# copy_deps_to_dist, although either would work. Clever programmers 
# might build it out of those LDFLAGS, plus some hand entries. I'm
# not that clever or maybe I know better.

SOLOCS = {}
SOLOCS['curl'] = "#{uldir}/libcurl.so.4"
SOLOCS['ungif'] = "#{uldir}/libungif.so.4"
SOLOCS['gif'] = "#{uldir}/libgif.so.4"
SOLOCS['jpeg'] = "#{ularch}/libjpeg.so.8"
SOLOCS['libyaml'] = "#{ularch}/libyaml.so"
if ENV['GTK'] == 'gtk+-2.0' && COPY_GTK == true
  SOLOCS['gtk2'] = "#{ularch}/libgtk-x11-2.0.so.0"
  SOLOCS['gdk2'] = "#{ularch}/libgdk-x11-2.0.so.0"
  SOLOCS['atk'] = "#{ularch}/libatk-1.0.so.0"
  SOLOCS['gio'] = "#{ularch}/libgio-2.0.so.0"
  SOLOCS['pangoft2'] = "#{ularch}/libpangoft2-1.0.so.0"
  SOLOCS['pangocairo'] = "#{ularch}/libpangocairo-1.0.so.0"
  SOLOCS['gdk_pixbuf'] = "#{ularch}/libgdk_pixbuf-2.0.so.0"
  SOLOCS['cairo'] = "#{ularch}/libcairo.so.2"
  SOLOCS['pango'] = "#{ularch}/libpango-1.0.so.0"
  SOLOCS['freetype'] = "#{ularch}/libfreetype.so.6"
  SOLOCS['fontconfig'] = "#{ularch}/libfontconfig.so.1"
  SOLOCS['pixman'] = "#{ularch}/libpixman-1.so.0"
  SOLOCS['gobject'] = "#{ularch}/libgobject-2.0.so.0"
  SOLOCS['glib'] = "#{larch}/libglib-2.0.so.0"
end
