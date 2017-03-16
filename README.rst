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

Example Usage
==============

.. code-block:: python

  from nodetrie import Node

  # This is the head of the trie, keep a reference to it
  node = Node()
  # Insert a linked tree so that a->b->c->d where -> means 'has child node'
  node.insert_split_path(['a', 'b', 'c', 'd'])
  node.children[0].name == 'a'
  a_node = node.children[0]
  a_node.name == 'a'
  a_node.children[0].name == 'b'

  # Insertions create only new nodes
  # Insert linked tree so that a->b->c->dd
  node.insert_split_path(['a', 'b', 'c', 'dd'])

  # Only one 'a' node
  len(node.children) == 1

  # 'c' node has two children, 'd' and 'dd'
  c_node = node.children[0].children[0].children[0]
  len(c_node.children) == 2

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
      print(path, _node.name)

Output

.. code-block:: python

  [u'a', u'b', u'c1', u'd1'] d1
  [u'a', u'b', u'c1', u'd2'] d2
  [u'a', u'b', u'c2', u'd1'] d1
  [u'a', u'b', u'c2', u'd2'] d2

A separator joined path list is return by the query function.

.. code:: python

  for match in node.query('a.b.*.*'):
      print(match)

  for match in node.query('a|b|*|*', separator='|'):
     print(match)

Output

.. code:: python

  (u'a.b.c1.d1', <nodetrie.nodetrie.Node at 0x7f1899fa7730>),
  (u'a.b.c1.d2', <nodetrie.nodetrie.Node at 0x7f1899fa7130>),
  (u'a.b.c2.d1', <nodetrie.nodetrie.Node at 0x7f1899fa7110>),
  (u'a.b.c2.d2', <nodetrie.nodetrie.Node at 0x7f1899fa73f0>)

  (u'a|b|c1|d1', <nodetrie.nodetrie.Node object at 0x7f436d09c750>)
  (u'a|b|c1|d2', <nodetrie.nodetrie.Node object at 0x7f436d09c770>)
  (u'a|b|c2|d1', <nodetrie.nodetrie.Node object at 0x7f436d09c790>)
  (u'a|b|c2|d2', <nodetrie.nodetrie.Node object at 0x7f436d09c7b0>)
