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

cimport cnode

cdef object PyNode_Init(cnode.Node *node)

cdef class Node:
    cdef cnode.Node *_node
    cdef bint _is_leaf(self, cnode.Node *node) nogil
    cdef cnode.Node* _insert(self, unsigned char *name) nogil
    cpdef void insert_split_path(self, list paths)
    cdef void _insert_split_path(self, unsigned char **paths) nogil
    cdef list _get_matched_children(self, sub_query, Node node)
    cpdef is_pattern(self, pattern)
    cdef bint _is_pattern(self, char *pattern) nogil
    # cpdef list to_array(self)
