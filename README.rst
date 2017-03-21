NodeTrie
==========

A Trie data structure library.

.. image:: https://img.shields.io/pypi/v/nodetrie.svg
  :target: https://pypi.python.org/pypi/nodetrie
  :alt: Latest Version
.. image:: https://travis-ci.org/NodeTrie/NodeTrie_Py.svg?branch=master
  :target: https://travis-ci.org/NodeTrie/NodeTrie_Py
  :alt: CI status

Installation
=============

::

  pip install nodetrie

Motivation, design goals
==========================

NodeTrie is a Python extension to a native C library written for this purpose.

It came about from a lack of viable alternatives for Python. While other trie library implementations exist, they suffer from severe limitations such as

* Read only structures, no insertions
* High memory use for large trees
* Lack of searching, particularly file mask or wild card style searching
* Slow inserts

Existing implementations on PyPi fall into these broad categories, including `Marissa-Trie <https://github.com/pytries/marisa-trie>`_ (read only) and `datrie <https://github.com/pytries/datrie>`_ (slow inserts, very high memory use for large trees).

NodeTrie's C library is designed to minimize memory use as much as possible and still allow arbitrary length trees that can be searched.

Each node has a name associated with it as its data, along with children list and number of children.

Features and design notes
==========================

* NodeTrie is an n-ary tree, meaning any one node can have any number of children
* Node children arrays are dynamically resized *as needed on insertion* on a per node basis. No fixed minimum nor maximum size
* Node names can be of arbitrary length, available memory allowing
* Node names from ``Node.name`` are always unicode in either Python 2/3
* Any python string type may be used on insertion
* Node names are implicitly decoded from unicode on insertion, if needed, with ``nodetrie.ENCODING`` (`utf-8`) default encoding which can be overridden
* New Python ``Node`` objects are created from the underlying C pointers every time ``Node.children`` is called. There is overhead on the Python interpreter to create these objects. It is safe and better performing to keep and re-use children references instead, see examples below

Limitations
=============

* Deletions are not implemented
* The C library implementation uses pointer arrays for children to reduce search space complexity and character pointers for names to allow for arbitrary name lengths. This may lead to memory fragmentation
* ``Node`` objects in python are read only. It is not possible to override the name of an existing ``Node`` object nor modify its attributes
* Character encodings that allow for null characters such as UCS-2 *should not be used*

Example Usage
==============

.. code-block:: python

  from nodetrie import Node

  # This is the root of the tree, keep a reference to it.
  # Deleting or letting the root node go out of scope will de-allocate
  # the entire tree
  node = Node()

  # Insert a linked tree so that a->b->c->d where -> means 'has child node'
  node.insert_split_path(['a', 'b', 'c', 'd'])
  node.children[0].name == 'a'

  # Sub-trees can be referred to by child nodes
  a_node = node.children[0]
  a_node.name == 'a'
  a_node.children[0].name == 'b'
  a_node.is_leaf() == False

  # Insertions create only new nodes
  # Insert linked tree so that a->b->c->dd
  node.insert_split_path(['a', 'b', 'c', 'dd'])

  # Only one 'a' node
  node.children_size == 1

  # Existing references to nodes will have correct children
  # after insertion without recreating the node object.
  # Here, a_node is an existing object prior to more nodes
  # being added to its sub-tree. After insertion, a's sub-tree contains newly
  # inserted nodes as expected

  # 'c' node is first child of 'b' which is first child of 'a'
  # 'c' node has two children, 'd' and 'dd'
  c_node = a_node.children[0].children[0]
  c_node.children_size == 2
  c_node.is_leaf() == False

  # 'd' and 'dd' are both leaf nodes
  leaf_nodes = [c for c in c_node.children if c.is_leaf()]
  len(leaf_nodes) == 2

.. note:: De-allocation

  Tree is de-allocated when and only when root node goes out of scope or is deleted. Letting sub-tree objects go out of scope or explicitly deleting them will *not de-allocate that sub-tree*.

.. note:: Sub-tree insertions

  Insertions on non-root nodes work as expected. However, ``Node.insert`` does *not* check if a node is already present, unlike ``Node.insert_split_path``

Searching
----------

NodeTrie supports exact name as well as file mask matching tree search.

.. code-block:: python

  from __future__ import print_function
  from nodetrie import Node

  node = Node()
  for paths in [['a', 'b', 'c1', 'd1'], ['a', 'b', 'c1', 'd2'],
                ['a', 'b', 'c2', 'd1'], ['a', 'b', 'c2', 'd2']]:
      node.insert_split_path(paths)
  for path, _node in node.search(node, ['a', 'b', '*', '*'], []):
      print(path, _node)

Output

.. code-block:: python

  [u'a', u'b', u'c1', u'd1'] Node: 'd1'
  [u'a', u'b', u'c1', u'd2'] Node: 'd2'
  [u'a', u'b', u'c2', u'd1'] Node: 'd1'
  [u'a', u'b', u'c2', u'd2'] Node: 'd2'

Separator joined node names for a matched sub-tree are returned by the query function.

.. code:: python

  for match in node.query('a.b.*.*'):
      print(match)

  for match in node.query('a|b|*|*', separator='|'):
     print(match)

Output

.. code:: python

  (u'a.b.c1.d1', Node: 'd1')
  (u'a.b.c1.d2', Node: 'd2')
  (u'a.b.c2.d1', Node: 'd1')
  (u'a.b.c2.d2', Node: 'd2')

  (u'a|b|c1|d1', Node: 'd1')
  (u'a|b|c1|d2', Node: 'd2')
  (u'a|b|c2|d1', Node: 'd1')
  (u'a|b|c2|d2', Node: 'd2')

Contributions are most welcome.
