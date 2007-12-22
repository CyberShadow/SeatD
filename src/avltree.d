/*  SEATD - Semantics Aware Tools for D
 *  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module avltree;

/**************************************************************************************************
    AVL Tree that balances itself after each insertion
**************************************************************************************************/
class AVLTree(T)
{
    alias AVLNode!(T) node_t;
    node_t  root;
    bool    rebalance;

    bool insert(T v)
    {
        if ( root is null ) {
            root = new AVLNode!(T)(v);
            return true;
        }
        else {
            rebalance = false;
            return insert(root, v);
        }
    }

    bool find(VT,RT)(VT v, out RT res)
    {
        return root.find(v, res);
    }

    int opApply(RT)(int delegate(ref RT v) proc)
    {
        if ( root is null )
            return 0;
        return root.traverseDepthLeft(proc);
    }

    private bool insert(node_t n, T v)
    {
        void updateParents(node_t top=null)
        {
            with ( n )
            {
                if ( top is null )
                    top = n;

                balance         = 0;
                parent.balance  = 0;

                node_t pp = parent.parent;
                if ( pp is null )
                    root = top;
                else
                {
                    if ( parent is pp.left )
                        pp.left = top;
                    else
                        pp.right = top;
                }
                parent.parent = top;
                top.parent = pp;
                if ( top !is n )
                    parent = top;
            }
        }

        with ( n )
        {
            if ( v < value )
            {
                if ( left is null )
                {
                    left = new node_t(v, n);
                    --balance;
                    if ( balance != 0 )
                        rebalance = true;
                }
                else if ( !insert(left, v) )
                    return false;
            }
            else if ( v > value )
            {
                if ( right is null )
                {
                    right = new node_t(v, n);
                    ++balance;
                    if ( balance != 0 )
                        rebalance = true;
                }
                else if ( !insert(right, v) )
                    return false;
            }
            else
                return false;

            if ( rebalance && parent !is null )
            {
                assert(balance != 0);
                if ( n is parent.left )
                {
                    if ( parent.balance > 0 )
                        --parent.balance;
                    else if ( parent.balance == 0 ) {
                        --parent.balance;
                        return true;
                    }
                    else
                    {
                        // single rotation to the right
                        if ( balance < 0 )
                        {
                            parent.left     = right;
                            if ( right !is null )
                                right.parent    = parent;
                            right           = parent;
                            updateParents;
                        }
                        // double rotation to the right
                        else
                        {
                            assert(right !is null);
                            node_t r            = right;
                            parent.left         = r.right;
                            if ( parent.left !is null )
                                parent.left.parent  = parent;
                            right               = r.left;
                            if ( right !is null )
                                right.parent    = n;
                            r.right             = parent;
                            r.left              = n;
                            updateParents(r);
                        }
                    }
                }
                else
                {
                    if ( parent.balance < 0 )
                        ++parent.balance;
                    else if ( parent.balance == 0 ) {
                        ++parent.balance;
                        return true;
                    }
                    else
                    {
                        // single rotation to the left
                        if ( balance > 0 )
                        {
                            parent.right    = left;
                            if ( left !is null )
                                left.parent     = parent;
                            left            = parent;
                            updateParents;
                        }
                        // double rotation to the left
                        else
                        {
                            assert(left !is null);
                            node_t l            = left;
                            parent.right        = l.left;
                            if ( parent.right !is null )
                                parent.right.parent = parent;
                            left                = l.right;
                            if ( left !is null )
                                left.parent     = n;

                            l.left              = parent;
                            l.right             = n;
                            updateParents(l);
                        }
                    }
                }
            }
            rebalance = false;
            return true;
        }
    }

    unittest
    {
        AVLTree!(int)  tree = new AVLTree!(int);
        for ( int i = 0; i < 100; ++i )
            tree.insert(i);

        bool checkOrder(AVLNode!(int) n)
        {
            if ( n.left !is null ) {
                assert(n.left.parent is n);
                assert(n.left.value < n.value);
            }
            if ( n.right !is null ) {
                assert(n.right.parent is n);
                assert(n.right.value >= n.value);
            }
            return true;
        }

        tree.traverseDepthLeft(&checkOrder);

        // check next
        for ( int i = 0; i < 99; ++i )
        {
            AVLNode!(int) n;
            assert(tree.find(i, n));
            assert(n.value == i);
            assert(n.findNext(n));
            assert(n.value == i+1, .toString(i+1)~" expected, "~.toString(n.value)~" found");
        }

        tree = new AVLTree!(int);
        for ( int i = 99; i >= 0; --i )
            tree.insert(i);
        tree.traverseDepthLeft(&checkOrder);

        // check next
        for ( int i = 0; i < 99; ++i )
        {
            AVLNode!(int) n;
            assert(tree.find(i, n));
            assert(n.value == i);
            assert(n.findNext(n));
            assert(n.value == i+1, .toString(i+1)~" expected, "~.toString(n.value)~" found");
        }
    }
}

class AVLNode(T)
{
    alias AVLNode!(T) node_t;
    node_t  parent, left, right;
    byte    balance;

    T       value;

    this(T v, node_t p = null)
    {
        value = v;
        parent = p;
    }

    int traverseDepthLeft(RT)(int delegate(ref RT v) proc)
    {
        int ret;
        static if ( is(RT == AVLNode!(T)) )
        {
            ret = proc(this);
            if ( ret )
                return ret;
        }
        static if ( is(RT == T) )
        {
            ret = proc(value);
            if ( ret )
                return ret;
        }
        static if ( !is(RT == AVLNode!(T)) && !is(RT == T) )
            static assert(0, "invalid result type for tree traversal");

        if ( left !is null ) {
            ret = left.traverseDepthLeft(proc);
            if ( ret )
                return ret;
        }
        if ( right !is null ) {
            ret = right.traverseDepthLeft(proc);
            if ( ret )
                return ret;
        }
        return 0;
    }

    bool findNext(RT)(inout RT res)
    {
        node_t n;
        if ( right is null )
        {
            bool found=false;
            for ( n = this; n.parent !is null; n = n.parent )
            {
                if ( n.parent.left is n ) {
                    static if ( is(T : Object) )
                        assert(n.parent.value > n.value, "\n"~n.parent.value.toString~"  parent of  "~n.value.toString~"\n");
                    assert(n.parent.value >  n.value);
                    n = n.parent;
                    found = true;
                    break;
                }
                assert(n.parent.value <= n.value);
            }
            if ( !found )
                return false;
        }
        else
        {
            assert(right.value >= value);
            n = right;
            while ( n.left !is null ) {
                static if ( is(T : Object) )
                    assert(n.left.value < n.value, "\n"~n.left.value.toString~"\tleft of\t"~n.value.toString~"\n");
                assert(n.left.value < n.value);
                n = n.left;
            }
        }

        static if ( is(RT == AVLNode!(T)) )
            res = n;
        static if ( is(RT == T) )
            res = n.value;
        static if ( !is(RT == AVLNode!(T)) && !is(RT == T) )
            static assert(0, "invalid result type for next node search");
        return true;
    }

    bool find(VT,RT)(VT v, inout RT res)
    {
        if ( v < value )
        {
            if ( left !is null )
                return left.find(v, res);
            return false;
        }
        if ( v > value )
        {
            if ( right !is null )
                return right.find(v, res);
            return false;
        }
        static if ( is(RT == AVLNode!(T)) )
            res = this;
        static if ( is(RT == T) )
            res = value;
        static if ( !is(RT == AVLNode!(T)) && !is(RT == T) )
            static assert(0, "invalid result type for tree search");
        return true;
    }
}
