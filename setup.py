"""Setup script for NodeTrie"""

from setuptools import setup, find_packages, Extension

import versioneer

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
    extensions = cythonize(
        extensions,
        compiler_directives={'embedsignature': True,}
        )

cmdclass = versioneer.get_cmdclass()

setup(
    name='nodetrie',
    version=versioneer.get_version(),
    cmdclass=cmdclass,
    url='https://github.com/NodeTrie/NodeTrie_Py',
    license='LGPLv2',
    author='Panos Kittenis',
    author_email='22e889d8@opayq.com',
    description=('Python bindings for NodeTrie, a trie data structure library'),
    long_description=open('README.rst').read(),
    packages=find_packages('.'),
    zip_safe=False,
    include_package_data=True,
    platforms='any',
    classifiers=[
        'Intended Audience :: Developers',
        'Operating System :: OS Independent',
        'Programming Language :: Python',
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.4',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Topic :: Scientific/Engineering :: Information Analysis',
        'Topic :: Software Development :: Libraries',
        'Topic :: Software Development :: Libraries :: Python Modules',
        'License :: OSI Approved :: GNU Library or Lesser General Public License (LGPL)',
        'License :: OSI Approved :: GNU Lesser General Public License v2 (LGPLv2)',
        ],
    ext_modules=extensions,
)
