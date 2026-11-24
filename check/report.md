# check/ report

300 random programs from seed 1000: 121 the same, 177 skipped, 2 different.

## Seed 1183: Beta++ --working and --final differ in standard output, status (0 against 139)

The program, as Ralph reads it:

```
proc p1
    var i1: Whole = 0;
    while i1 < 1
        i1 = i1 + 1;
    end while
end proc p1

proc p2[a3: Bool, a4: Bool] -> Whole
    let v5: Text = be.Text(18);
    p1();
    var v6: Text = v5;
    return (be.Whole(v6) ?? 3) + 19;
end proc p2

proc.main
    show_msg("score hi there x-y");
end proc.main
```

As Beta++ reads it:

```
proc p1:
    var $i1: Whole = 0;
    while $i1 < 1:
        $i1 = $i1 + 1;
    end while
end proc p1

proc p2[$a3: Bool, $a4: Bool] returns Whole:
    let $v5: Text = be.Text(18);
    p1();
    var $v6: Text = $v5;
    return (be.Whole($v6) ?? 3) + 19;
end proc p2

proc.main:
    show_msg("score hi there x-y");
end proc.main
```

Input: ""

Ralph: status 0, output "score hi there x-y\n", messages ""

Beta++ --working: status 0, output "score hi there x-y\n", messages ""

## Seed 1186: Beta++ --working and --final differ in standard output, status (0 against 139)

The program, as Ralph reads it:

```
proc p2[a1: Whole, a2: Whole]
    if (a1 + a2) at_least (a1 + a1)
    else
        show_msg("A:B {a1} hi there");
        let v6: Text = "{a1}";
        let v7: Whole = a1;
    end if
end proc p2

proc.main
    var i10: Whole = 0;
    while i10 < 4
        p2(2, i10);
        var v11: Whole = be.Whole("ok.") ?? 8;
        i10 = i10 + 1;
    end while
end proc.main
```

As Beta++ reads it:

```
proc p2[$a1: Whole, $a2: Whole]:
    if ($a1 + $a2) at_least ($a1 + $a1):
    else:
        show_msg.fmt("A:B {$a1} hi there");
        let $v6: Text = be.Text.fmt("{$a1}");
        let $v7: Whole = $a1;
    end if
end proc p2

proc.main:
    var $i10: Whole = 0;
    while $i10 < 4:
        p2(2, $i10);
        var $v11: Whole = be.Whole("ok.") ?? 8;
        $i10 = $i10 + 1;
    end while
end proc.main
```

Input: ""

Ralph: status 0, output "A:B 2 hi there\nA:B 2 hi there\n", messages ""

Beta++ --working: status 0, output "A:B 2 hi there\nA:B 2 hi there\n", messages ""

