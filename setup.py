from __future__ import print_function
import platform
import sys
import versioneer
from setuptools import setup, find_packages, Extension, Distribution as _Distribution
from distutils.errors import CCompilerError
from distutils.errors import DistutilsExecError
from distutils.errors import DistutilsPlatformError
from distutils.command.build_ext import build_ext

cpython = platform.python_implementation() == 'CPython'

try:
    from Cython.Build import cythonize
except ImportError:
    USING_CYTHON = False
else:
    USING_CYTHON = True

ext = 'pyx' if USING_CYTHON else 'c'

extensions = [Extension("nodetrie.nodetrie",
                        ["nodetrie/nodetrie.%s" % (ext,),
                         "nodetrie_c/src/node.c",],
                         depends=["nodetrie_c/src/node.h"],
                         include_dirs=["nodetrie_c/src"],
                         extra_compile_args=["-std=c99", "-O3"],
                         ),
             ]

if USING_CYTHON:
    extensions = cythonize(extensions)
        
cmdclass = versioneer.get_cmdclass()

class Distribution(_Distribution):

    def has_ext_modules(self):
        # We want to always claim that we have ext_modules. This will be fine
        # if we don't actually have them (such as on PyPy) because nothing
        # will get built, however we don't want to provide an overally broad
        # Wheel package when building a wheel without C support. This will
        # ensure that Wheel knows to treat us as if the build output is
        # platform specific.
        return True

setup(
    name='nodetrie',
    version=versioneer.get_version(),
    cmdclass=cmdclass,
    url='https://github.com/NodeTrie/NodeTrie_Py',
    license='apache2',
    author='P Kittenis',
    author_email='22e889d8@opayq.com',
    description=('Python bindings for NodeTrie, a trie data structure library'),
    long_description=open('README.rst').read(),
    packages=find_packages('.'),
    zip_safe=False,
    include_package_data=True,
    platforms='any',
    classifiers=[
        'Intended Audience :: Developers',
        'License :: OSI Approved :: Apache Software License',
        'Operating System :: OS Independent',
        'Programming Language :: Python',
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 3',
        'Topic :: Scientific/Engineering :: Information Analysis',
        'Topic :: Software Development :: Libraries',
        'License :: OSI Approved :: GNU Library or Lesser General Public License (LGPL)',
        'License :: OSI Approved :: GNU Lesser General Public License v2 (LGPLv2)',
        ],
    distclass=Distribution,
    ext_modules=extensions,
)
