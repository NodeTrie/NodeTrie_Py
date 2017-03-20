# cython: boundscheck=False, wraparound=False, optimize.use_switch=True

# This file is part of NodeTrie.
# Copyright (C) 2017 Panos Kittenis

# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation, version 2.1.

# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

import fnmatch

from libc.stdlib cimport malloc, free
from cpython.version cimport PY_MAJOR_VERSION
cimport cnode

ENCODING='utf-8'

cdef bytes _encode_bytes(_str):
    if isinstance(_str, bytes):
        return _str
    elif PY_MAJOR_VERSION < 3 and isinstance(_str, unicode):
        return _str.encode(ENCODING)
    elif PY_MAJOR_VERSION >= 3 and isinstance(_str, str):
        return bytes(_str, ENCODING)
    return bytes(_str)

cdef unsigned char ** to_cstring_array(list list_str):
    cdef unsigned char **ret = <unsigned char **>malloc(
        (len(list_str)+1) * sizeof(unsigned char *))
    if not ret:
        raise MemoryError()
    cdef bytes _str
    cdef Py_ssize_t i
    for i in range(len(list_str)):
        list_str[i] = _encode_bytes(list_str[i])
        ret[i] = <unsigned char *>list_str[i]
    ret[i+1] = NULL
    return ret

cdef object PyNode_Init(cnode.Node *node):
    """Python Node object factory class for cnode.Node*"""
    cdef Node _node = Node()
    _node._node = node
    return _node

# Graphite-API functions ported to cython from graphite-api project
# http://graphite-api.readthedocs.org/
def _deduplicate(list entries):
    cdef set yielded = set()
    for entry in entries:
        if entry not in yielded:
            yielded.add(entry)
            yield entry

# Graphite-API functions ported to cython from graphite-api project
# http://graphite-api.readthedocs.org/
cdef match_entries(node, pattern):
    """A drop-in replacement for fnmatch.filter that supports pattern
    variants (ie. {foo,bar}baz = foobaz or barbaz).

    Ported to Cython and made to use Node object instead of path"""
    cdef list ch_nodes = [_node for _node in node.children]
    cdef list node_names = [_node.name for _node in ch_nodes]
    cdef list variations
    cdef list variants
    cdef list matching
    v1, v2 = pattern.find('{'), pattern.find('}')

    if v1 > -1 and v2 > v1:
        variations = pattern[v1+1:v2].split(',')
        variants = [pattern[:v1] + v + pattern[v2+1:] for v in variations]
        matching = []

        for variant in variants:
            matching.extend(fnmatch.filter(node_names, variant))

        # remove dupes without changing order
        matching = list(_deduplicate(matching))
        return [_node for _node in ch_nodes if _node.name in matching]
    matching = fnmatch.filter(node_names, pattern)
    return [_node for _node in ch_nodes if _node.name in matching]


cdef class Node:
    """Node class wrapper for cnode.Node.
    Implements init, clear, insertion and is_leaf of Node definitions
    as well as tree queries with wildcard pattern
    """

    def __cinit__(self):
        self._node = NULL

    def __dealloc__(self):
        if self._node is not NULL and self._node.name is NULL:
            cnode.clear(self._node)

    property children:
        """Get node children list

        :rtype: list(:py:class:`Node`)"""
        def __get__(self):
            if self._node is NULL:
                return []
            if self._node.children_i == 0:
                return []
            cdef unsigned int i
            return [PyNode_Init(&self._node.children[i])
                    for i in range(self._node.children_i)]

    property children_size:
        """Get children list size

        :rtype: int"""
        def __get__(self):
            if self._node is not NULL:
                return self._node.children_i

    property name:
        """Get node name

        :rtype: unicode
        """
        def __get__(self):
            if self._node is not NULL and self._node.name is not NULL:
                return self._node.name.decode(ENCODING)

    def is_leaf(self):
        """Check if node is a leaf

        :rtype: bool
        """
        return self._is_leaf(self._node)

    cdef bint _is_leaf(self, cnode.Node *node) nogil:
        return cnode.is_leaf(node)

    def insert(self, path, str separator='.'):
        """Insert tree path string as nodes separated by separator

        :param path: str
        :param separator: Separator to split path on"""
        cdef list paths = path.split(separator)
        return self.insert_split_path(paths)

    cdef cnode.Node* _insert(self, unsigned char *name) nogil:
        return cnode.insert(self._node, name)

    cpdef void insert_split_path(self, list paths):
        """Insert tree paths list

        :param paths: List of paths to insert"""
        if len(paths) == 0:
            return
        cdef unsigned char **c_paths = to_cstring_array(paths)
        self._insert_split_path(c_paths)

    cdef void _insert_split_path(self, unsigned char **paths) nogil:
        if self._node == NULL:
            self._node = cnode.init_node()
        _node = self._node
        cnode.insert_paths(self._node, paths)
        free(paths)

    def query(self, query, separator='.'):
        """Return nodes matching Graphite glob pattern query"""
        cdef list nodes = sorted(self.search(self, query.split(separator), []))
        cdef Node node
        return ((separator.join(path), node,)
                for path, node in nodes)

    cdef list _get_matched_children(self, sub_query, Node node):
        if self.is_pattern(sub_query):
            return match_entries(node, sub_query)
        cdef Node _node
        return [_node for _node in node.children
                if _node.name == sub_query]

    def search(self, Node node, list split_query, list split_path):
        """Return matching children for each query part in split query starting
        from given node"""
        sub_query = split_query[0]
        matched_children = self._get_matched_children(sub_query, node)
        cdef Node child_node
        cdef list child_path
        cdef list child_query
        for child_node in matched_children:
            child_path = split_path[:]
            child_path.append(child_node.name)
            child_query = split_query[1:]
            if len(child_query) > 0:
                for sub in self.search(child_node, child_query, child_path):
                    yield sub
            else:
                yield (child_path, child_node)

    cpdef is_pattern(self, pattern):
        byte_str = _encode_bytes(pattern)
        cdef char* c_pattern = byte_str
        return self._is_pattern(c_pattern)

    cdef bint _is_pattern(self, char *pattern) nogil:
        return cnode.is_pattern(pattern)
