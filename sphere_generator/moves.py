"""
moves.py

Author: Jonah Miller (jonah.maxwell.miller@gmail.com)

This file is part of the sphere_generator program which generates
spheres of (as close as possible to) uniform curvature for a given
surface area by monte carlo simulation.

This file contains move functions for monte carlo moves.

Each move has 3 functions associated with it: 
     --- A complex generator which takes a vertex as input and calculates 
         all possible combinations of triangles around that vertex which 
         would be topologically acceptable for the move to operate on.
     --- A try function which takes a vertex as input and 
         calls the complex generator function and randomly selects 
         an acceptable complex. The try function then uses the methods 
         defined in state_tracking to calculate how the move will effect 
         global values such as the mean and standard deviation of the 
         sphere's curvature. This information can then be sent to the 
         Monte Carlo Metropolis algorithm to calculate whether or not to 
         accept the move. The try function returns the expected change in
         state and the complex that will be modified.
     --- An apply function actually applies a move to the spacetime. 
         It accepts a subcomplex as input. It has side effects.
"""


### Dependencies
#-------------------------------------------------------------------------
import numpy as np
import scipy as sp
import random
# Class data structures we need
import simplex_ancestors as sa
import simplex_descendants as sd
import state_manipulation as sm
import utilities as ut
import error_checking
import initialization
import state_tracking as st
#-------------------------------------------------------------------------


####---------------------------------------------------------------------####
#                               Classes                                     #
####---------------------------------------------------------------------####
# The complex class contains information about a set of simplices onto
# which it is topologically acceptable to apply a move to.
#---------------------------------------------------------------------------
class generalized_complex:
    """
    The complex class contains information about a set of simplices onto
    which it is topologically acceptable to apply a move to.

    Accepts triangle instances, lists of triangle ids, or lists of
    lists of triangle ids. This is the primary advantage of the
    complex class over just a list.

    The generalized_complex class is the parent class for complex
    child classes, which are for specialized purposes (for special
    moves, for instance). It should rarely if ever be called.
    """
    
    def __init__(self,triangle_list):
        triangle_id_list = []
        for t in triangle_list:
            if isinstance(t,sd.triangle):
                triangle_id_list.append(t.id)
            elif type(t) == list or type(t) == set or type(t) == tuple:
                triangle_id_list += list(t)
            elif type(t) == int:
                triangle_id_list.append(t)
            else:
                raise TypeError("Input to moves.complex must " + 
                                "be a collection, a triangle, or an ID.")
            self.triangles = set(triangle_id_list)
  
    def __str__(self):
        return str(self.triangles)

    def __len__(self):
        return len(self.triangles)

    def get_triangles(self):
        return self.triangles

class complex(generalized_complex):
    """
    The complex class contains information about a set of simplices onto
    which it is topologically acceptable to apply a move to.

    Accepts triangle instances, lists of triangle ids, or lists of
    lists of triangle ids. This is the primary advantage of the
    complex class over just a list.
    """
    
class complex22(generalized_complex):
    """
    The complex22 class is the same as the complex class, but includes
    a method to set the pair of vertices that share an edge between
    the two triangles in the complex and a method to set the pair of
    vertices that DO NOT share an edge for the two triangles in the
    complex. For use with complex_2_to_2, try_2_to_2, and move_2_to_2.
    """
    def set_shared_vertices(self,vertex_pair):
        """
        The 2->2 move requires a pair of vertices with 4 triangles
        attached to each of them. These vertices are the endpoints for
        the edge shared between the two triangles in the
        complex. These are they.
        """
        if len(vertex_pair) != 2:
            raise TypeError("We need a PAIR of vertices!")
        self.shared_vertices = [sd.vertex.parse_input(v)\
                                    for v in vertex_pair]

    def get_shared_vertices(self):
        """
        The 2->2 move requires a pair of vertices with 4 triangles
        attached to each of them. These vertices are the endpoints for
        the edge shared between the two triangles in the
        complex. These are they.
        """
        return self.shared_vertices

    def set_unshared_vertices(self,vertex_pair):
        """
        The 2->2 move requires a pair of vertices that don't share an
        edge but are vertices of of the two triangles in the
        complex. These are they.
        """
        if len(vertex_pair) != 2:
            raise TypeError("We need a PAIR of vertices!")
        self.unshared_vertices = [sd.vertex.parse_input(v)\
                                      for v in vertex_pair]

    def get_unshared_vertices(self):
        """
        The 2->2 move requires a pair of vertices that don't share an
        edge but are vertices of of the two triangles in the
        complex. These are they.
        """
        return self.unshared_vertices

#---------------------------------------------------------------------------

   

####---------------------------------------------------------------------####
#                               Functions                                   #
####---------------------------------------------------------------------####

# Utility functions
#---------------------------------------------------------------------------
def extract_triangle(simplex_id_or_simplex):
    "Given a simplex id or simplex, returns the simplex."
    if type(simplex_id_or_simplex) == int:
        triangle = sd.triangle.instances[simplex_id_or_simplex]
    elif isinstance(simplex_id_or_simplex,sd.triangle):
        triangle = simplex_id_or_simplex
    else:
        raise ValueError("Move functions can only accept ints or triangles.")
    return triangle

def check_area_decreasing_validity(decrease):
    """
    If the area decrease of a move, decrease, would cause the sphere
    to cease to be topologically accpetable, return False. Otherwise,
    return True.  
    """
    min_acceptable_area = 4
    if sd.triangle.count_instances() - decrease < min_acceptable_area:
        return False
    else:
        return True

def set_neighbors_and_triangles(changed_vertices,changed_triangle_ids):
    """
    For each changed vertex in a move, finds and sets its triangles.
    For each triangle added in a move, connects it to its neihgbors.
    Finally, runs some error checking. Accepts collections only.
    """
    # Set triangles associated with a vertex
    for v in changed_vertices:
        v.find_and_set_triangles()
        v.find_and_set_edges()
        
    # Set triangle neighbors
    for v in changed_vertices:
        v.connect_surrounding_triangles()

    # Finally run some error checking:
    for t_id in changed_triangle_ids:
        sd.triangle.instances[t_id].check_topology_v2()
        sd.triangle.instances[t_id].check_edge_validity()
        sd.triangle.instances[t_id].check_neighbor_edge_correlation()

def try_random(allowed_move_list):
    """
    Randomly attempts to apply a random move from the allowed move
    list. Returns movedata.
    """
    # The move we will attempt
    try_move = random.choice(allowed_move_list)
    # The simplex we will work on
    try_simplex = random.choice(sd.triangle.instances.values())
    # Try the move, return the movedata
    mdata = try_move(try_simplex)

    return mdata

def apply_move(move_data):
    """
    Apply the move specified in move_data
    """
    # The function we apply the move with
    move_function = move_data.get_move_type()
    # The complex we apply the move on
    cmpx = move_data.get_complex()
    # Do the move!
    return move_function(cmpx)

#---------------------------------------------------------------------------


# Functions for the 1->3 move
#---------------------------------------------------------------------------
"""
Move behavior: Add a vertex in the center of the triangle and connect it to 
               each of the other 3 vertices.
      0                 0
     / \               /|\
    /   \     -->     / | \
   /     \           /  0  \
  /       \         /  / \  \
 0---------0       0---------0

Volume increase: 2
"""
def complex_1_to_3(simplex_id_or_simplex):
    """
    Takes a simplex or simplex id as input and calculates what, if
    any, complices are topologically acceptable to operate on.

    The 1->3 move is by far the easiest of these, since it is
    trivially topologically acceptable for one and only one
    simplex. However, for completeness, it's included.
    """
    # Extract info
    triangle = extract_triangle(simplex_id_or_simplex)

    return complex([triangle.id])

def try_1_to_3(simplex_id_or_simplex):
    """
    Tries a 1->3 move and returns the move data that the metropolis
    algorithm will use to decide whether or not to accept a move. Also
    returns useful information for applying the move.
    """
    # The complex
    cmpx = complex_1_to_3(simplex_id_or_simplex)

    # The triangle id. There should only be one.
    if len(cmpx.get_triangles()) == 1:
        triangle_id = list(cmpx.get_triangles())[0]
    else:
        raise ValueError("There should be only one "+
                         "triangle for the 1->3 complex.")

    # The triangle
    triangle = sd.triangle.instances[triangle_id]

    # The original vertices
    original_vertices = [sd.vertex.instances[p] for p in triangle.vertices]

    # We're adding 1 vertex, but each of 3 other vertices is connected
    # to 1 additional triangle each.

    # "replace" the 3 original vertices
    removed_vertices = [st.imaginary_vertex(len(v),False) \
                            for v in original_vertices]
    added_vertices = [st.imaginary_vertex(len(v)+1,True) \
                          for v in original_vertices]
    # Add the center vertex
    added_vertices.append(st.imaginary_vertex(3,True))

    return st.move_data(removed_vertices + added_vertices,
                        cmpx,move_1_to_3,2)

def move_1_to_3(cmpx):
    "Applies a 1->3 move to the input complex, cmpx."
    # Extract the single triangle required for this move.
    if len(cmpx.get_triangles()) == 1:
        triangle_id = list(cmpx.get_triangles())[0]
    else:
        raise ValueError("There should be only one "+
                         "triangle for the 1->3 complex.")
    triangle = sd.triangle.instances[triangle_id]

    # Vertices
    original_vertices = triangle.get_vertices()
    
    # Edges 
    original_edges = triangle.get_edges()

    # Endpoints of edges
    endpoints = [e.get_vertex_ids() for e in original_edges]

    # Make the point that will trisect the triangle
    v = sd.vertex()
    sd.vertex.add(v)

    # Generate the vertices for the three new triangles to be created
    vertex_list = [points | set([v.get_id()]) for points in endpoints]
    
    # Make the new triangles
    new_triangles = [sm.build_triangle_and_edges(tri) for tri in vertex_list]

    # Delete the old triangle
    sm.remove_triangle(triangle)

    # Set neighbors, triangles for each vertex, and do some error checking
    vertex_ids = ut.set_union(vertex_list)
    vertices = [sd.vertex.instances[i] for i in vertex_ids]
    set_neighbors_and_triangles(vertices,new_triangles)

    return True
#---------------------------------------------------------------------------


# Functions for the 3->1 move
#---------------------------------------------------------------------------
"""
Move behavior: Undo the 1->3 move.

      0                 0
     /|\               / \
p   / | \     -->     /   \
   /  0  \           /     \
  /  / \  \         /       \
 0---------0       0---------0

Volume decrease: 2
"""
def complex_3_to_1(simplex_id_or_simplex):
    """
    Takes a simplex or simplex id as input and calculates what, if
    any, complices are topologically acceptable to operate on.

    The 3->1 move requires a vertex that is attached to 3
    simplices. There is a slight danger that volume decreasing moves
    can make a system topologically unacceptable. If this is the case,
    then the function returns False.

    If there is more than one acceptable complex, returns one at
    random.
    """
    volume_decrease = 2
    if not check_area_decreasing_validity(volume_decrease):
        return False

    # Extract triangle
    triangle = extract_triangle(simplex_id_or_simplex)

    # Extract vertices
    vertices = triangle.get_vertices()

    # If a vertex has only three triangles, consider it
    ids = lambda x: x.get_triangle_ids() # For convenience
    possibilities = [ids(v) for v in vertices if len(ids(v)) == 3]
    
    # Each boundary point on a possible complex must be attached to at
    # least 4 triangles
    # Function to extract vertex class objects from a triangle id
    obj = lambda i: sd.triangle.instances[i].get_vertices()
    # function to extract the boundary points of a complex possibility
    boundaries = lambda c: ut.set_union([set(obj(t)) for t in c]) \
        - ut.set_intersection([set(obj(t)) for t in c])
    # Function that tells us if every boundary vertex of a possibility
    # is connected to greater than 3 simplex
    acceptable = lambda p: len([b for b in boundaries(p) if len(b) > 3]) == 3

    # Only accept a possibility if each boundary vertex has 4 or more
    # triangles.
    complices = [complex(p) for p in possibilities if acceptable(p)]

    if len(complices) == 1:
        return complices[0]
    elif len(complices) > 1:
        return random.choice(complices)
    else:
        return False

def try_3_to_1(simplex_id_or_simplex):
    """
    Tries a 3->1 move and returns the move data that the metropolis
    algorithm will use to decide whether or not to accept the move. If
    the move is simply not topologically acceptable, returns false.
    """
    # The complex
    cmpx = complex_3_to_1(simplex_id_or_simplex)
    
    # If there are no topologically acceptable complices, stop right
    # now and return False. Otherwise, extract the triangles.
    if cmpx:
        triangles = cmpx.get_triangles()
    else:
        return False

    # Now that we have the triangle, extract the list of points of
    # each triangle.
    old_vertices = [sd.triangle.instances[t].get_vertices() \
                        for t in triangles]
    # The central vertex is the intersection of all the vertices in
    # the old triangles
    central_vertex = ut.set_intersection([set(t) for t in old_vertices])
    # The boundary vertices are the union of the vertices of the old
    # triangles minus the intersection:
    boundary_vertices = ut.set_union([set(t) for t in old_vertices]) \
        - central_vertex

    # We're removing the central vertex, but each boundary vertex will
    # be attached to 1 fewer triangle.
    
    # "Replace" the 3 original vertices
    removed_vertices = [st.imaginary_vertex(len(v),False) \
                            for v in boundary_vertices]
    added_vertices = [st.imaginary_vertex(len(v)-1,True) \
                          for v in boundary_vertices]
    # "Remove" the center vertex
    removed_vertices.append(st.imaginary_vertex(3,False))

    return st.move_data(removed_vertices + added_vertices,cmpx,
                        move_3_to_1,-2)

def move_3_to_1(cmpx):
    "Applies a 3->1 move to the input complex, cmpx."

    # Extract the complex, which contains three triangles.
    if len(cmpx.get_triangles()) == 3:
        original_triangles = [sd.triangle.instances[i] \
                                  for i in cmpx.get_triangles()]
    else:
        raise ValueError("There should be exactly 3 triangles for the " +
                         "3->1 complex.")

    # Extract the boundary vertices
    original_vertices = [set(t.get_vertices()) for t in original_triangles]
    central_vertex = list(ut.set_intersection(original_vertices))[0]
    boundary_vertices = ut.set_union(original_vertices) \
        - set([central_vertex])
    boundary_vertex_ids = [v.get_id() for v in boundary_vertices]

    # Extract the edges to be removed (there are 3)
    # Lambda functions for clarity
    get_edges = lambda i: set(sd.triangle.instances[i].get_edges())
    intersected_element = lambda L: ut.only_element(ut.set_intersection(L))
    # Nested list comprehensions: take the intersection of the set of
    # edges associated with pairs of the triangles we care
    # about. These edges are flagged for deleteion.
    shared_edges = [intersected_element([get_edges(i) for i in c]) \
                        for c in ut.k_combinations(cmpx.get_triangles())]
    # There should only be 3 shared edges. If there are more, we messed up.
    assert len(shared_edges) == 3
    
    # Make the new triangle
    new_triangle = sm.build_triangle_and_edges(boundary_vertex_ids)

    # Clean up
    for t in original_triangles: # Delete the old triangles:
        sm.remove_triangle(t)
    for e in shared_edges: # Delete the old edges.
        sm.remove_edge(e)
    sd.vertex.delete(central_vertex) # Delete the old vertex

    # Set triangles, neihgbors, and check topology
    set_neighbors_and_triangles(boundary_vertices,[new_triangle])

    return True
#---------------------------------------------------------------------------


# Functions for the 2->2 move
#---------------------------------------------------------------------------
"""
Move behavior: Given two triangles that share an edge, rotate the
               configuration by ninety degrees.

               For the move to work properly, the new edge must not already
               exist. Furthermore, the vertices marked "1" below must be each
               connected to 4 or more triangles before the move is applied.

               Since the volume is unchanged, we don't have to check
               to see if the volume change will make the move
               topologically unacceptable.

      0                   0
     / \                 /|\
    /   \               / | \
   /     \             /  |  \
  /       \           /   |   \
 1---------1   -->   1    |    1
  \       /           \   |   /
   \     /             \  |  /
    \   /               \ | /
     \ /                 \|/
      0                   0
"""

def complex_2_to_2(simplex_id_or_simplex):
    """
    Takes a simplex or simplex id as input and calculates what, if
    any, complices are topologically acceptable to operate on. If
    there's more than one, return one at random. If there are none,
    return False.

    The 2->2 move equires that the new edge not already exist (there
    are cases when it does) and that the endpoints of the deleted edge
    each have >=4 triangles attached to them before the move is
    applied.
    """
    # Declare local constants
    pair_length = 2 # The length of a pair 
    neighbor_length = 3 # The number of vertices a triangle must have.

    # Extract data for the first triangle
    # Extract triangle
    t1 = extract_triangle(simplex_id_or_simplex)
    # Extract neighbors
    t1_neighbors = t1.get_neighbors()
    # Extract vertices
    t1_vertices = t1.get_vertices()

    # If we can find a pair of vertices of t1 that each have >=4
    # triangles attached, then these vertices might be good choices of
    # endpoints for the edge we will delete.
    possible_endpoints = [v for v in t1_vertices if len(v) >= 4]

    # If there are fewer than two possible endpoints, no acceptable
    # edge exists, so me might as well give up.
    if len(possible_endpoints) < 2:
        return False
    else: # If >=2 possible endpoints exist, get all possible pairs:
        possible_endpoint_pairs = ut.k_combinations(possible_endpoints,2)
    
    # The other triangle in the complex will be the neighbor that
    # shares the chosen pair of of endpoint vertices. We want to keep
    # track of which pair this is associated with.
    acceptable_neighbors = [(p,n) for p in possible_endpoint_pairs \
                                for n in t1_neighbors \
                                if p.issubset(n.get_vertices())]

    # We will be making an edge between the unshared vertices of the
    # two neighboring triangles. We have to make sure that this edge
    # does not yet exist. 

    # A function to calculate the unshared vertices as a pair. Just
    # syntactic sugar.
    unshared_v = lambda p,n: ut.set_union([set(t1.get_vertices()),
                                           set(n.get_vertices())]) - set(p)
    # An acceptable complex has a pair of shared points, a neighbor,
    # and a pair of unshared points which are not the endpoints of an
    # existing edge.
    acceptable_cmpxs = [(p,n,unshared_v(p,n))\
                             for (p,n) in acceptable_neighbors \
                             if not sd.edge.exists(unshared_v(p,n))]

    # Double check to make sure we have what we expect.
    acceptable_cmpxs = [(p,n,u) for (p,n,u) in acceptable_cmpxs \
                            if len(p) == pair_length\
                            and len(n) == neighbor_length\
                            and len(u) == pair_length]

    # We have everything. If it exists, stick it in a complex and
    # return it. Otherwise, return false.
    if acceptable_cmpxs:
        chosen_complex = random.choice(acceptable_cmpxs)
        triangles = [t1,chosen_complex[1]]
        shared_vertices = chosen_complex[0]
        unshared_vertices = chosen_complex[2]
        cmpx = complex22(triangles)
        cmpx.set_shared_vertices(shared_vertices)
        cmpx.set_unshared_vertices(unshared_vertices)
        return cmpx
    else:
        return False

def try_2_to_2(simplex_id_or_simplex):
    """
    Tries a 2->2 move and returns the data that the metropolis
    algorithm will use to decide whether ornot to accept the
    move. Also returns useful information for applying the move.
    """
    # The complex
    cmpx = complex_2_to_2(simplex_id_or_simplex)

    # If no complex is possible, immediately return false
    if not cmpx:
        return False

    # The triangles in the complex. There should be 2.
    triangles = [sd.triangle.parse_input(t) for t in cmpx.get_triangles()]
    if len(triangles) != 2:
        raise ValueError("There should be 2 triangles in this complex!")

    # The unshared vertices. There should be 2, but complex22 does
    # this error checking for us. It also returns instances rather
    # than values in the case of the vertices.
    unshared_vertices = cmpx.get_unshared_vertices()
    # The shared vertices. Similar to the unshared
    shared_vertices = cmpx.get_shared_vertices()

    # All 4 of the original vertices will be replaced.
    original_vertices = unshared_vertices + shared_vertices
    assert len(set(original_vertices)) == 4
    removed_vertices = [st.imaginary_vertex(len(v),False) \
                            for v in original_vertices]

    # The unshared vertices will become shared, so each one will
    # become attached to one additional triangle.
    added_vertices = [st.imaginary_vertex(len(v)+1,True) \
                          for v in unshared_vertices]
    # The shared vertices will become unshared, so each one will
    # become attached to one less triangle.
    added_vertices += [st.imaginary_vertex(len(v)-1,True) \
                           for v in shared_vertices]

    return st.move_data(removed_vertices + added_vertices,
                        cmpx, move_2_to_2,0)

def move_2_to_2(cmpx):
    """
    Applies a 2->2 move to the input complex, cmpx. Input must be of
    type complex22.
    """
    # Declare local constants
    triangle_size = 3 # The number of veritces in a triangle
    complex_size = 2 # The complex has 2 triangles
    number_of_shared_vertices = 2 # The complex has 2 shared vertices
    number_of_unshared_vertices = 2 # The complex has 2 unshared vertices
    total_number_of_vertices = 4 # There should be a total of 4
                                 # vertices in the complex.

    # Extract the triangles. Don't need error checking because if the
    # complexd is not correct, we won't be able to extract the shared
    # and unshared vertices.
    triangles = [sd.triangle.parse_input(t) for t in cmpx.get_triangles()]
    # Extract the shared_vertices
    shared_vertices = cmpx.get_shared_vertices()
    # Extract the unshared vertices
    unshared_vertices = cmpx.get_unshared_vertices()

    # Tiny bit of error checking just in caes
    assert len(triangles) == complex_size
    assert len(shared_vertices) == number_of_shared_vertices
    assert len(unshared_vertices) == number_of_unshared_vertices
    assert len(set(shared_vertices+unshared_vertices)) \
        == total_number_of_vertices

    # The edge shared by the two shared vertices. If it doesn't
    # exist, something went very wrong!
    if sd.edge.exists(shared_vertices):
        shared_edge = sd.edge.exists(shared_vertices)[0]
    else:
        raise ValueError("The pair of vertices you gave me are not "
                         + "endpoints of an edge!")

    # Calculate the vertices for the new triangles
    new_triangles = [set(unshared_vertices+[s]) for s in shared_vertices \
                         if len(set(unshared_vertices+[s])) == triangle_size]
    # Tiny bit of error checking just in case. The number of new
    # triangles should be the same as the number of old triangles.
    assert len(new_triangles) == complex_size

    # Remove the old triangles
    for t in triangles:
        sm.remove_triangle(t)
    # Remove the old edge we no longer need.
    sm.remove_edge(shared_edge)

    # With the old geometric constructs out of the way, make the new one!
    new_triangles = [sm.build_triangle_and_edges(point_list) \
                         for point_list in new_triangles]

    # Connect triangles and connect the triangles to their respective edges
    changed_vertices = shared_vertices + unshared_vertices
    set_neighbors_and_triangles(changed_vertices,new_triangles)

    return True

#---------------------------------------------------------------------------


### Various constants
###-----------------------------------------------------------------------
# All try functions. Useful for the Metropolis Algorithm
list_of_try_functions = [try_1_to_3,try_3_to_1,try_2_to_2]
# Try functions for volume increasing moves. Useful for initialization.
list_of_volume_increasing_functions = [try_1_to_3,try_2_to_2]
###-----------------------------------------------------------------------


