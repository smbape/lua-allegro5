from typing import Callable, List, Optional

from pycparser import c_ast
from pycparser.c_generator import CGenerator as CGeneratorBaseBuggy

from pycparserext.ext_c_parser import FuncDeclExt, TypeDeclExt


class CGeneratorBase(CGeneratorBaseBuggy):
    # bug fix
    def visit_UnaryOp(self, n):
        operand = self._parenthesize_unless_simple(n.expr)
        if n.op == "p++":
            return "%s++" % operand
        elif n.op == "p--":
            return "%s--" % operand
        elif n.op == "sizeof":
            # Always parenthesize the argument of sizeof since it can be
            # a name.
            return "sizeof(%s)" % self.visit(n.expr)
        elif n.op == "__alignof__":
            return "__alignof__(%s)" % self.visit(n.expr)
        else:
            # avoid merging of "- - x" or "__real__varname"
            return "%s %s" % (n.op, operand)


class AsmAndAttributesMixin:
    def visit_Asm(self, n):
        components = [
                n.template,
                ]
        if (n.output_operands is not None
                or n.input_operands is not None
                or n.clobbered_regs is not None):
            components.extend([
                n.output_operands,
                n.input_operands,
                n.clobbered_regs,
                ])

        return " %s(%s)" % (
                n.asm_keyword,
                " : ".join(
                    self.visit(c) for c in components))

    def _generate_type(
        self,
        n: c_ast.Node,
        modifiers: List[c_ast.Node] = [],
        emit_declname: bool = True,
    ) -> str:
        """ Recursive generation from a type node. n is the type node.
            modifiers collects the PtrDecl, ArrayDecl and FuncDecl modifiers
            encountered on the way down to a TypeDecl, to allow proper
            generation from it.
        """
        # ~ print(n, modifiers)
        match n:
            case c_ast.TypeDecl() | TypeDeclExt():
                s = ""
                if n.quals:
                    s += " ".join(n.quals) + " "
                s += self.visit(n.type)

                nstr = n.declname if n.declname and emit_declname else ""
                # Resolve modifiers.
                # Wrap in parens to distinguish pointer to array and pointer to
                # function syntax.
                #
                for i, modifier in enumerate(modifiers):
                    match modifier:
                        case c_ast.ArrayDecl():
                            if i != 0 and isinstance(modifiers[i - 1], c_ast.PtrDecl):
                                nstr = "(" + nstr + ")"
                            nstr += "["
                            if modifier.dim_quals:
                                nstr += " ".join(modifier.dim_quals) + " "
                            if modifier.dim is not None:
                                nstr += self.visit(modifier.dim)
                            nstr += "]"
                        case c_ast.FuncDecl():
                            if i != 0 and isinstance(modifiers[i - 1], c_ast.PtrDecl):
                                nstr = "(" + nstr + ")"
                            args = (
                                self.visit(modifier.args)
                                if modifier.args is not None
                                else ""
                            )
                            nstr += "(" + args + ")"
                        case FuncDeclExt():
                            if i != 0 and isinstance(modifiers[i - 1], c_ast.PtrDecl):
                                nstr = "(" + nstr + ")"
                            args = (
                                self.visit(modifier.args)
                                if modifier.args is not None
                                else ""
                            )
                            nstr += "(" + args + ")"

                            if modifier.asm is not None:
                                nstr += " " + self.visit(modifier.asm)

                            if modifier.attributes.exprs:
                                nstr += (
                                        " __attribute__(("
                                        + self.visit(modifier.attributes)
                                        + "))")
                        case c_ast.PtrDecl():
                            if modifier.quals:
                                quals = " ".join(modifier.quals)
                                suffix = f" {nstr}" if nstr else ""
                                nstr = f"* {quals}{suffix}"
                            else:
                                nstr = "*" + nstr

                if hasattr(n, "asm") and n.asm:
                    nstr += self.visit(n.asm)

                if hasattr(n, "attributes") and n.attributes.exprs:
                    nstr += " __attribute__((" + self.visit(n.attributes) + "))"

                if nstr:
                    s += " " + nstr
                return s
            case c_ast.Decl():
                return self._generate_decl(n.type)
            case c_ast.Typename():
                return self._generate_type(n.type, emit_declname=emit_declname)
            case c_ast.IdentifierType():
                return " ".join(n.names) + " "
            case c_ast.ArrayDecl() | c_ast.PtrDecl() | c_ast.FuncDecl() | FuncDeclExt():
                return self._generate_type(
                    n.type, modifiers + [n], emit_declname=emit_declname
                )
            case _:
                return self.visit(n)

    def visit_AttributeSpecifier(self, n):
        return "__attribute__((" + self.visit(n.exprlist) + "))"


class GnuCGenerator(AsmAndAttributesMixin, CGeneratorBase):
    def _funcspec_to_str(self, i):
        if isinstance(i, c_ast.Node):
            return self.visit(i)
        else:
            return i

    def _generate_decl(self, n):
        """Generation from a Decl node."""
        s = ""
        if n.funcspec:
            s = " ".join(self._funcspec_to_str(i) for i in n.funcspec) + " "
        if n.storage:
            s += " ".join(n.storage) + " "
        if n.align:
            s += self.visit(n.align[0]) + " "
        s += self._generate_type(n.type)
        return s

    def visit_FuncDeclExt(self, n: FuncDeclExt) -> str:
        return self._generate_type(n)

    def visit_TypeOfDeclaration(self, n):
        return "%s(%s)" % (n.typeof_keyword, self.visit(n.declaration))

    def visit_TypeOfExpression(self, n):
        return "%s(%s)" % (n.typeof_keyword, self.visit(n.expr))

    def visit_TypeList(self, n):
        return ", ".join(self.visit(ch) for ch in n.types)

    def visit_RangeExpression(self, n):
        return "%s ... %s" % (self.visit(n.first), self.visit(n.last))

    def visit_Struct(self, n):
        """Generate code for struct, handling attributes if present."""
        s = self._generate_struct_union_enum(n, "struct")
        # If this is a StructExt with attributes, add them
        if hasattr(n, "attrib") and n.attrib:
            s += " " + self.visit(n.attrib)
        return s

    def visit_StructExt(self, n):
        """Generate code for StructExt with attributes."""
        return self.visit_Struct(n)


class GNUCGenerator(GnuCGenerator):
    def __init__(self):
        from warnings import warn
        warn("GNUCGenerator is now called GnuCGenerator",
                DeprecationWarning, stacklevel=2)


class OpenCLCGenerator(AsmAndAttributesMixin, CGeneratorBase):
    def visit_FileAST(self, n):
        s = ""
        from pycparserext.ext_c_parser import PreprocessorLine
        for ext in n.ext:
            if isinstance(ext, (c_ast.FuncDef, PreprocessorLine)):
                s += self.visit(ext)
            else:
                s += self.visit(ext) + ";\n"
        return s

    def visit_PreprocessorLine(self, n):
        return n.contents

# vim: fdm=marker
