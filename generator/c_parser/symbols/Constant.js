class Constant {
    constructor({
        sign,
        value
    }, loc) {
        this.sign = sign;
        this.value = value;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        cb(this, parents);
    }
}

exports.Constant = Constant;
