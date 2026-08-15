class Translationunit {
    constructor(declarations, loc) {
        this.declarations = declarations;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);
        for (const declaration of this.declarations) {
            declaration.visit(cb, parents);
        }
        parents.pop();
        cb(this, parents);
    }
}

exports.Translationunit = Translationunit;
